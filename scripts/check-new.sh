#!/bin/sh
# vm/new against runevm (docs/plans/middle-end.md, M5): every program of
# tests/lang and tests/perf compiled for each -- the register bytecode for
# vm/new, the stack bytecode for runevm -- and run as tests/run-tests.sh runs
# it, must allocate the same bytes and objects (runevm --count), the cheap
# check of a back end and a VM together; the compiler, compiled to the
# register bytecode and run by vm/new, must make of its own sources the
# bytecode runevm's makes; and tests/opt/prims.sml, the primitives vm/new
# does in its loop on their edge cases (vm/new/fastprim.h), must print on
# vm/new what it prints on runevm. What each prints is tests/run-tests.sh's
# to check (make test-new).
#   scripts/check-new.sh [--rune BIN] [--vm BIN] [--new BIN] [-j N]
set -u
cd "$(dirname "$0")/.."
rune=bin/rune
vm=bin/runevm
new=bin/runevm-new
jobs=$(sh scripts/ncpus.sh)
one=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    --new) new=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    *) echo "usage: scripts/check-new.sh [--rune BIN] [--vm BIN] [--new BIN] [-j N]" >&2; exit 2 ;;
  esac
done
out=tests/out/new-check
mkdir -p "$out"

# --one BASE: one program, BASE without .sml; prints a line when it fails.
# Each runs in its own directory, under the same name, so that what the
# program is told of itself (CommandLine.name) is as long on both.
if [ -n "$one" ]; then
  name=$(echo "$one" | tr '/' '_')
  args=""; [ -f "$one.args" ] && args=$(cat "$one.args")
  vmargs=""; [ -f "$one.vmargs" ] && vmargs=$(cat "$one.vmargs")
  stdin=/dev/null; [ -f "$one.stdin" ] && stdin=$one.stdin
  for side in stack new; do
    mkdir -p "$out/$side"
    if [ $side = new ]; then flags=--target=registers; run=$new; else flags=""; run=$vm; fi
    # shellcheck disable=SC2086
    if ! "$rune" $flags "$one.sml" -o "$out/$side/$name.rbc" 2> "$out/$side/$name.cerr"; then
      echo "FAIL new.$name: $side: $(grep -m1 . "$out/$side/$name.cerr")"; exit 0
    fi
    # shellcheck disable=SC2086
    "$run" --count $vmargs "$out/$side/$name.rbc" $args < "$stdin" > /dev/null 2> "$out/$side/$name.err"
    sed -n 's/^runevm: count: [0-9]* instructions, //p' "$out/$side/$name.err" > "$out/$side/$name.alloc"
  done
  if ! cmp -s "$out/stack/$name.alloc" "$out/new/$name.alloc"; then
    echo "FAIL new.$name: runevm and vm/new allocate differently ($(cat "$out/stack/$name.alloc") / $(cat "$out/new/$name.alloc"))"
  fi
  exit 0
fi

progs=$(ls tests/lang/*.sml tests/perf/*.sml | sed 's/\.sml$//')
n=$(echo "$progs" | wc -l | tr -d ' ')
fails=$(echo "$progs" | xargs -P "$jobs" -I{} sh "$0" --rune "$rune" --vm "$vm" --new "$new" --one {})

# the compiler on each VM, making its own bytecode
srcs="build/config.sml $(grep -v '^#' sources.txt | tr '\n' ' ') src/main/rune-main.sml"
boot=""
# shellcheck disable=SC2086
if ! "$rune" --target=registers -o "$out/rune.new.rbc" $srcs 2> "$out/boot.err"; then
  boot="FAIL new.bootstrap: the compiler does not compile to the register bytecode: $(head -1 "$out/boot.err")"
else
  # shellcheck disable=SC2086
  "$vm" --heap-size 67108864 bin/rune.rbc --lib lib -o "$out/by-stack.rbc" $srcs 2> "$out/boot.err" &&
  "$new" --heap-size 67108864 "$out/rune.new.rbc" --lib lib -o "$out/by-new.rbc" $srcs 2>> "$out/boot.err" ||
    boot="FAIL new.bootstrap: $(head -1 "$out/boot.err")"
  if [ -z "$boot" ] && ! cmp -s "$out/by-stack.rbc" "$out/by-new.rbc"; then
    boot="FAIL new.bootstrap: the compiler on vm/new makes other bytecode than on runevm"
  fi
fi

# the primitives done in the loop, on their edge cases, against runevm
prims=""
if ! "$rune" tests/opt/prims.sml -o "$out/prims.rbc" 2> "$out/prims.err" ||
   ! "$rune" --target=registers tests/opt/prims.sml -o "$out/prims.new.rbc" 2>> "$out/prims.err"; then
  prims="FAIL new.prims: $(head -1 "$out/prims.err")"
else
  "$vm" "$out/prims.rbc" > "$out/prims.stack.out" 2>&1
  "$new" "$out/prims.new.rbc" > "$out/prims.new.out" 2>&1
  if ! cmp -s "$out/prims.stack.out" "$out/prims.new.out"; then
    prims="FAIL new.prims: tests/opt/prims.sml prints on vm/new other than on runevm: $(diff "$out/prims.stack.out" "$out/prims.new.out" | head -2 | tail -1)"
  fi
fi

if [ -n "$fails$boot$prims" ]; then
  [ -n "$fails" ] && echo "$fails"
  [ -n "$boot" ] && echo "$boot"
  [ -n "$prims" ] && echo "$prims"
  echo "check-new: $(printf '%s\n%s\n%s\n' "$fails" "$boot" "$prims" | grep -c FAIL) of $n programs, the bootstrap and the primitives fail"
  exit 1
fi
echo "check-new: $n programs allocate the same on vm/new and runevm, the compiler on vm/new makes the bytecode it makes on runevm, and the primitives done in the loop print the same"
