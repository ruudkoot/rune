#!/bin/sh
# The language suite and tests/vm on the Windows VMs (`make test-windows`):
#   tests/run-windows.sh [--rune BIN] [--vm EXE]... [--native BIN] [--def FILE] [-j N] [FILTER]
# Every program of tests/lang whose name contains FILTER is compiled once,
# with the ordinary compiler -- the bytecode is the same for every VM -- and
# run on each VM named by --vm (bin/runevm.exe and bin/runevm32.exe when none
# is), N at a time, except the programs tests/windows-skip.txt lists; its
# header gives the reasons. What a program must print and how it must exit
# are checked as tests/run-tests.sh checks them, from the same siblings
# (.args, .vmargs, .stdin, .exitcode, .stderr, .cwarn). The results of
# bin/runevmSUFFIX.exe go to tests/out/windowsSUFFIX. Then tests/vm runs on
# each VM, and a few programs run with --count on each and on bin/runevm:
# the counts of instructions, bytes and objects must be the same, since a
# value and an object have the same layout on all three. Last, an image of
# Runtime.save crosses between the two systems both ways, which is the one
# thing about vm/image.c that only two machines can show. For vm/new
# (docs/plans/jit.md, M2) the same, with --rune bin/rune-new, --vm
# bin/runevm-new.exe --vm bin/runevm-new32.exe, --native bin/runevm-new for
# the VM of this system and --def vm/new/regs.def for tests/vm.
#
# The VMs do not run in this tree but in a directory on the Windows side,
# which tests/windows-dir.sh finds and says why. Each program runs in a
# directory of its own there, with the .rbc beside it and an empty
# tests/out, which two programs of the suite write into. TZ reaches the VMs
# through WSLENV, so they run in the time zone the other runners use.
#
# Running an .exe needs Windows, or WSL, which starts one for you. Nothing
# else in the tree depends on this: it is not part of make check.
set -u
TZ='NST3:30NDT,M3.2.0,M11.1.0'
export TZ
WSLENV="TZ${WSLENV:+:$WSLENV}"
export WSLENV

rune=bin/rune
native=bin/runevm
def=vm/opcodes.def
vms=""
jobs=""
filter=""
mode=""
while [ $# -gt 0 ]; do
  case $1 in
    --rune) rune=$2; shift 2 ;;
    --vm) vms="$vms $2"; shift 2 ;;
    --native) native=$2; shift 2 ;;
    --def) def=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --compile-one|--run-one) mode=$1; shift ;;
    -*) echo "usage: $0 [--rune BIN] [--vm EXE]... [--native BIN] [--def FILE] [-j N] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
cd "$(dirname "$0")/.."
root=$(pwd)
rbcdir=tests/out/windows-rbc

# ---------------------------------------------------------------- workers
# --compile-one NAME: compile tests/lang/NAME.sml into $rbcdir and write
# NAME.cresult there: PASS, or "FAIL NAME: why".
if [ "$mode" = --compile-one ]; then
  name=$filter
  base=tests/lang/$name
  if ! "$rune" "$base.sml" -o "$rbcdir/$name.rbc" 2> "$rbcdir/$name.cerr"; then
    echo "FAIL $name: compile error: $(head -1 "$rbcdir/$name.cerr")"
  elif [ -f "$base.cwarn" ] && ! cmp -s "$rbcdir/$name.cerr" "$base.cwarn"; then
    echo "FAIL $name: compiler warnings differ (diff $base.cwarn $rbcdir/$name.cerr)"
  elif [ ! -f "$base.cwarn" ] && [ -s "$rbcdir/$name.cerr" ]; then
    echo "FAIL $name: unexpected compiler output: $(head -1 "$rbcdir/$name.cerr")"
  else
    echo PASS
  fi > "$rbcdir/$name.cresult"
  exit 0
fi

# --run-one NAME with VM, OUT and RUNDIR in the environment: run NAME on VM
# in RUNDIR/NAME and write OUT/NAME.result.
if [ "$mode" = --run-one ]; then
  name=$filter
  base=$root/tests/lang/$name
  out=$root/$OUT
  dir=$RUNDIR/$name
  rm -rf "$dir"
  mkdir -p "$dir/tests/out"
  cp "$rbcdir/$name.rbc" "$dir/$name.rbc"
  args=""; [ -f "$base.args" ] && args=$(cat "$base.args")
  vmargs=""; [ -f "$base.vmargs" ] && vmargs=$(cat "$base.vmargs")
  stdin=/dev/null; [ -f "$base.stdin" ] && stdin=$base.stdin
  want=0; [ -f "$base.exitcode" ] && want=$(cat "$base.exitcode")
  # shellcheck disable=SC2086
  (cd "$dir" && "$VM" $vmargs "$name.rbc" $args < "$stdin" > "$out/$name.stdout" 2> "$out/$name.stderr")
  code=$?
  if [ "$code" != "$want" ]; then
    echo "FAIL $name: exit code $code, expected $want: $(head -1 "$out/$name.stderr")"
  elif ! cmp -s "$out/$name.stdout" "$base.expected"; then
    echo "FAIL $name: stdout differs (diff tests/lang/$name.expected $OUT/$name.stdout)"
  elif [ -f "$base.stderr" ] && ! cmp -s "$out/$name.stderr" "$base.stderr"; then
    echo "FAIL $name: stderr differs (diff tests/lang/$name.stderr $OUT/$name.stderr)"
  else
    echo PASS
  fi > "$out/$name.result"
  exit 0
fi

# ---------------------------------------------------------------- setup
[ -n "$vms" ] || vms="bin/runevm.exe bin/runevm32.exe"
[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh 2> /dev/null || echo 4)
for vm in $vms; do
  [ -x "$vm" ] || { echo "run-windows: $vm is missing (make windows)" >&2; exit 2; }
  if ! "$vm" --version > /dev/null 2>&1; then
    echo "run-windows: $vm will not start here; Windows or WSL is needed" >&2
    exit 2
  fi
done

if ! windir=$(sh tests/windows-dir.sh); then
  echo "run-windows: no directory on the Windows side; set RUNE_WINDOWS_DIR" >&2
  exit 2
fi

skip=tests/windows-skip.txt
skipped() { [ -f "$skip" ] && grep -q "^$1 " "$skip"; }

mkdir -p "$rbcdir"
rm -f "$rbcdir"/*.cresult
names=""
nskip=0
for src in tests/lang/*.sml; do
  name=$(basename "$src" .sml)
  case $name in *"$filter"*) ;; *) continue ;; esac
  if skipped "$name"; then nskip=$((nskip + 1)); continue; fi
  names="$names $name"
done

# ---------------------------------------------------------------- compile
if [ -n "$names" ]; then
  # shellcheck disable=SC2086
  printf '%s\n' $names | xargs -n 1 -P "$jobs" sh tests/run-windows.sh --rune "$rune" --compile-one
fi

# ---------------------------------------------------------------- run
status=0
summary=""
for vm in $vms; do
  suffix=$(basename "$vm" .exe); suffix=${suffix#runevm}
  OUT=tests/out/windows$suffix
  RUNDIR=$windir/windows$suffix
  mkdir -p "$OUT"
  rm -f "$OUT"/*.result
  rm -rf "$RUNDIR"
  mkdir -p "$RUNDIR"
  VM=$root/$vm
  export OUT RUNDIR VM
  run=""
  for name in $names; do
    if [ "$(cat "$rbcdir/$name.cresult" 2> /dev/null)" = PASS ]; then run="$run $name"; fi
  done
  if [ -n "$run" ]; then
    # shellcheck disable=SC2086
    printf '%s\n' $run | xargs -n 1 -P "$jobs" sh tests/run-windows.sh --run-one
  fi
  pass=0; fail=0
  : > "$OUT/failures.txt"
  for name in $names; do
    result=$(cat "$rbcdir/$name.cresult" 2> /dev/null)
    [ "$result" = PASS ] && result=$(cat "$OUT/$name.result" 2> /dev/null)
    case $result in
      PASS) pass=$((pass + 1)) ;;
      *) [ -n "$result" ] || result="FAIL $name: no result"
         echo "$result" >> "$OUT/failures.txt"
         fail=$((fail + 1)) ;;
    esac
  done
  if [ "$fail" != 0 ]; then
    echo "--- $vm"
    cat "$OUT/failures.txt"
    status=1
  fi

  # tests/vm, in the directory on the Windows side
  sh tests/vm/run-vm-tests.sh --vm "$vm" --out "$RUNDIR/vm" --def "$def" > "$OUT/vm.txt" 2>&1 || status=1
  grep '^FAIL' "$OUT/vm.txt"

  # the layout: --count on this VM and on the VM of this system (--native)
  layout="not checked"
  if [ -z "$filter" ] && [ -x "$native" ]; then
    layout=ok
    for name in rt.gc_stress rt.deeprec_stack rt.closure_capture rt.equality_structural; do
      vmargs=""; [ -f "tests/lang/$name.vmargs" ] && vmargs=$(cat "tests/lang/$name.vmargs")
      # shellcheck disable=SC2086
      want=$("$native" --count $vmargs "$rbcdir/$name.rbc" 2>&1 > /dev/null | grep '^runevm: count:')
      # shellcheck disable=SC2086
      got=$(cd "$RUNDIR/$name" 2> /dev/null && "$VM" --count $vmargs "$name.rbc" 2>&1 > /dev/null | tr -d '\r' | grep '^runevm: count:')
      if [ -z "$want" ] || [ "$want" != "$got" ]; then
        echo "FAIL layout $name on $vm: \"$got\", where $native gives \"$want\""
        layout=failed
        status=1
      fi
    done
  fi
  # An image across the two systems, both ways. Runtime.save writes the whole
  # running program to a file and `runevm --restore` carries it on, and nothing
  # in that file belongs to a machine or a system (vm/image.c): what this VM
  # saves, bin/runevm must take up, and the other way about. The program prints
  # its answer before saving and again when restored, so the two are compared
  # with each other and nothing is written down here.
  image="not checked"
  name=rt.save_restore_cross
  if [ -z "$filter" ] && [ -x "$native" ] && [ -f "$rbcdir/$name.rbc" ]; then
    image=ok
    idir=$RUNDIR/image$suffix
    rm -rf "$idir"
    mkdir -p "$idir/tests/out"
    cp "$rbcdir/$name.rbc" "$idir/prog.rbc"
    img=tests/out/$name.img
    # this VM saves, bin/runevm restores
    want=$(cd "$idir" && rm -f "$img" && "$VM" prog.rbc 2>&1 | tr -d '\r')
    got=$(cd "$idir" && "$root/$native" --restore "$img" 2>&1)
    if [ -z "$want" ] || [ "$want" != "$got" ]; then
      echo "FAIL image $vm -> $native: \"$got\", where it was saved as \"$want\""
      image=failed
      status=1
    fi
    # bin/runevm saves, this VM restores
    want=$(cd "$idir" && rm -f "$img" && "$root/$native" prog.rbc 2>&1)
    got=$(cd "$idir" && "$VM" --restore "$img" 2>&1 | tr -d '\r')
    if [ -z "$want" ] || [ "$want" != "$got" ]; then
      echo "FAIL image $native -> $vm: \"$got\", where it was saved as \"$want\""
      image=failed
      status=1
    fi
  fi
  summary="$summary
windows$suffix ($vm): passed $pass, failed $fail, skipped $nskip; $(tail -1 "$OUT/vm.txt"); layout $layout; image $image"
done
echo "${summary#?}"
exit $status
