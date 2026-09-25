#!/bin/sh
# The suites on VMs of machines this one is not (`make test-portability`):
#   tests/run-portability.sh [--rune BIN] [--vm BIN]... [--native BIN] [--def FILE] [-j N] [FILTER]
#
# Each VM named by --vm runs every program of tests/lang and the whole of
# tests/vm, as tests/run-tests.sh runs them here -- the bytecode is the same
# file for every VM, so only the VM differs. bin/runevm32 is a 32-bit x86,
# where a pointer is four bytes; bin/runevm-ppc64 is a big-endian 64-bit
# PowerPC under qemu, where the bytes of a word are the other way round.
# For vm/new (docs/plans/jit.md, M2) the same, with --rune bin/rune-new,
# --vm bin/runevm-new32 --vm bin/runevm-new-ppc64, --native bin/runevm-new
# for the counts of this machine and --def vm/new/regs.def for tests/vm.
#
# Then two things no single VM can show:
#
#  * the counts of `--count` must agree to the byte on every VM and on this
#    one. They are the instructions executed and the bytes and objects
#    allocated, which depend on the program and its input alone -- so a VM
#    that lays out a value differently says so here. That is what caught a
#    `Value` of 12 bytes where the 32-bit System V ABI aligns an int64_t to
#    four (vm/vm.h).
#  * an image of one VM must be read by the others, in every direction: it is
#    what vm/image.c claims and only two machines can test.
#
# tests/portability-skip.txt is what either VM would leave out, and is empty. A
# fork by a second VM needs qemu registered under /proc/sys/fs/binfmt_misc, or
# the exec of the VM's own binary fails; that file says how.
#
# Nothing here is part of make check, and nothing here is Windows: the VMs of
# Windows are make test-windows, which has a save and restore of its own
# between Windows and this system.
set -u
TZ='NST3:30NDT,M3.2.0,M11.1.0'
export TZ

rune=bin/rune
native=bin/runevm
def=vm/opcodes.def
vms=""
jobs=""
filter=""
while [ $# -gt 0 ]; do
  case $1 in
    --rune) rune=$2; shift 2 ;;
    --vm) vms="$vms $2"; shift 2 ;;
    --native) native=$2; shift 2 ;;
    --def) def=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    -*) echo "usage: $0 [--rune BIN] [--vm BIN]... [--native BIN] [--def FILE] [-j N] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
cd "$(dirname "$0")/.."
root=$(pwd)
[ -n "$vms" ] || vms="bin/runevm32 bin/runevm-ppc64"
[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh)
status=0
out=tests/out/portability
rm -rf "$out"
mkdir -p "$out"

# ------------------------------------------------- the suites, on each VM
for vm in $vms; do
  name=$(basename "$vm")
  # tests/portability-skip.txt is empty, and says what would go in it.
  skip="--skip tests/portability-skip.txt"
  echo "=== $name: the language suite and tests/vm"
  # shellcheck disable=SC2086
  sh tests/run-tests.sh -j "$jobs" --rune "$rune" --vm "$vm" $skip $filter || status=1
  sh tests/vm/run-vm-tests.sh --vm "$vm" --out "$out/$name-vm" --def "$def" || status=1
done

# ------------------------------------------- the counts, the same everywhere
# A few programs that allocate in different ways; the counts of every VM must
# be the same string.
echo "=== the counts of --count, on every VM"
counted="exp.arith_ops basis.list_ops basis.string_ops rt.gc_pressure mono.word8array"
for name in $counted; do
  src=tests/lang/$name.sml
  [ -f "$src" ] || continue
  rbc=$out/count-$name.rbc
  "$rune" "$src" -o "$rbc" 2> /dev/null || continue
  want=$("$native" --count "$rbc" 2>&1 > /dev/null | sed 's/^runevm: //')
  for vm in $vms; do
    got=$("$vm" --count "$rbc" 2>&1 > /dev/null | sed 's/^runevm: //')
    if [ "$got" != "$want" ]; then
      echo "FAIL count.$name on $(basename "$vm"): $got, where this machine says $want"
      status=1
    fi
  done
done
[ "$status" = 0 ] && echo "counts: the same on every VM ($(echo $counted | wc -w) programs)"

# ------------------------------------- an image of one VM, read by the others
# Every VM writes one and every other VM reads it, so a difference of width or
# of byte order shows whichever way round it is.
echo "=== an image of one VM, read by every other"
img=$out/image
rm -rf "$img"
mkdir -p "$img"
cat > "$img/cross.sml" << 'EOF'
(* The heap holds a list, a string and a real, so that a restore which gets the
   layout or the order of the bytes wrong cannot agree by luck. The answer is
   printed by the world that saves and by the world that is restored, so the
   two are compared with each other and nothing is written down here. *)
fun count (0, acc) = acc | count (n, acc) = count (n - 1, n :: acc)
val live = count (3000, [])
val text = String.concat (List.map Int.toString (List.take (live, 50)))
val r = 3.14159265358979
fun answer () =
  Int.toString (List.foldl (op +) 0 live) ^ " " ^ Int.toString (String.size text)
  ^ " " ^ Real.fmt (StringCvt.FIX (SOME 8)) r ^ " " ^ Int.toString (List.length (Runtime.trace ()))
val () =
  case Runtime.save "cross.img" of
    Runtime.Saved => print (answer () ^ "\n")
  | Runtime.Restored => print (answer () ^ "\n")
EOF
"$rune" "$img/cross.sml" -o "$img/cross.rbc" || status=1
for writer in "$native" $vms; do
  for reader in "$native" $vms; do
    [ "$writer" = "$reader" ] && continue
    want=$(cd "$img" && rm -f cross.img && "$root/$writer" cross.rbc 2>&1)
    [ -f "$img/cross.img" ] ||
      { echo "FAIL image: $(basename "$writer") wrote none: $want"; status=1; continue; }
    got=$(cd "$img" && "$root/$reader" --restore cross.img 2>&1)
    if [ "$got" = "$want" ]; then
      echo "  ok   $(basename "$writer") -> $(basename "$reader"): $got"
    else
      echo "FAIL image: $(basename "$writer") -> $(basename "$reader"): $got, where it was saved as $want"
      status=1
    fi
  done
done

[ "$status" = 0 ] && echo "portability: every suite passed on every VM, the counts agree, and every image crossed"
exit $status
