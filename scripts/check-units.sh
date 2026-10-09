#!/bin/sh
# Every program of tests/lang and tests/perf compiled whole, as `rune`
# compiles it, and with --units -- each file of the basis library and of
# the program a unit of its own, compiled after the ones before it and
# linked (docs/plans/incremental-compilation.md, M2) -- at -O0, -O1 and -O2,
# with the lint of every pass on. Each is run --checked as
# tests/run-tests.sh runs the program -- its .args, .stdin and .vmargs --
# and must print the same as the whole program, on both streams, traces
# included, and exit the same: the differential check of separate
# compilation, as check-levels is of the optimisations. The -O1 build
# writes its unit files too (--emit-units), which linked from the files
# must give the same bytes, and which loaded one by one into a running
# program (tests/units/load.sml, Runtime.load) must print the same on
# standard output and exit the same; its traces have the loader's frames
# below the program's. Left out of it: a program given arguments, since the
# loader takes the files as its arguments; one given options of the VM
# (.vmargs), which limit the heap for the program and not for the loader
# too; and the programs of loaded_skip, which print their own call stack.
#   scripts/check-units.sh [--rune BIN] [--vm BIN] [--out DIR] [-j N] [FILTER]
# The files are left in DIR (tests/out/units unless --out says otherwise).
set -u
cd "$(dirname "$0")/.."
rune=bin/rune
vm=bin/runevm
jobs=$(sh scripts/ncpus.sh)
one=""
filter=""
loader=""
out=tests/out/units
# the programs whose output is their call stack, below which the loader's
# frames are: Runtime.trace's frames and their number
loaded_skip="tests/lang/rt.trace_frames tests/lang/rt.trace_inlined tests/lang/rt.save_restore_cross"
usage="usage: scripts/check-units.sh [--rune BIN] [--vm BIN] [--out DIR] [-j N] [FILTER]"
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    --loader) loader=$2; shift 2 ;;
    -*) echo "$usage" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
mkdir -p "$out"

# --one BASE: one program, BASE without .sml; prints a line when it fails
if [ -n "$one" ]; then
  name=$(echo "$one" | tr '/' '_')
  builds="whole units.O0 units.O1 units.O2"
  for b in $builds; do
    case $b in
      whole) flags="" ;;
      units.O1) rm -rf "$out/$name.files"; flags="--units -O1 --emit-units $out/$name.files" ;;
      units.O*) flags="--units -${b#units.}" ;;
    esac
    # shellcheck disable=SC2086
    if ! "$rune" $flags --lint "$one.sml" -o "$out/$name.$b.rbc" 2> "$out/$name.$b.cerr"; then
      if [ $b = whole ]; then exit 0; fi   # a program that does not compile is tests/errors' business
      echo "FAIL units.$name: $flags: $(grep -m1 . "$out/$name.$b.cerr")"; exit 0
    fi
  done
  # the unit files of the -O1 build, linked from the files: the same bytes
  # shellcheck disable=SC2046
  if ! "$rune" -o "$out/$name.relinked.rbc" $(cat "$out/$name.files/units") 2> "$out/$name.relinked.cerr"; then
    echo "FAIL units.$name: linking its unit files: $(grep -m1 . "$out/$name.relinked.cerr")"; exit 0
  fi
  if ! cmp -s "$out/$name.units.O1.rbc" "$out/$name.relinked.rbc"; then
    echo "FAIL units.$name: its unit files linked differ from --units (cmp $out/$name.units.O1.rbc $out/$name.relinked.rbc)"; exit 0
  fi
  args=""; [ -f "$one.args" ] && args=$(cat "$one.args")
  vmargs=""; [ -f "$one.vmargs" ] && vmargs=$(cat "$one.vmargs")
  stdin=/dev/null; [ -f "$one.stdin" ] && stdin=$one.stdin
  for b in $builds; do
    # shellcheck disable=SC2086
    "$vm" --checked $vmargs "$out/$name.$b.rbc" $args < "$stdin" > "$out/$name.$b.out" 2> "$out/$name.$b.err"
    echo $? > "$out/$name.$b.code"
  done
  for b in units.O0 units.O1 units.O2; do
    for part in out err code; do
      if ! cmp -s "$out/$name.whole.$part" "$out/$name.$b.$part"; then
        echo "FAIL units.$name: whole and $b differ ($part: diff $out/$name.whole.$part $out/$name.$b.$part)"; exit 0
      fi
    done
  done
  # the unit files loaded into a running program
  case " $loaded_skip " in *" $one "*) loader="" ;; esac
  if [ -n "$loader" ] && [ ! -f "$one.args" ] && [ ! -f "$one.vmargs" ]; then
    # shellcheck disable=SC2046,SC2086
    "$vm" --checked $vmargs "$loader" $(cat "$out/$name.files/units") < "$stdin" > "$out/$name.loaded.out" 2> "$out/$name.loaded.err"
    echo $? > "$out/$name.loaded.code"
    for part in out code; do
      if ! cmp -s "$out/$name.units.O1.$part" "$out/$name.loaded.$part"; then
        echo "FAIL units.$name: its units loaded differ ($part: diff $out/$name.units.O1.$part $out/$name.loaded.$part; $out/$name.loaded.err)"; exit 0
      fi
    done
  fi
  exit 0
fi

progs=$(ls tests/lang/*.sml tests/perf/*.sml | sed 's/\.sml$//' | grep -e "$filter")
n=$(echo "$progs" | wc -l | tr -d ' ')
"$rune" tests/units/load.sml -o "$out/load.rbc" || { echo "check-units: tests/units/load.sml does not compile"; exit 1; }
fails=$(echo "$progs" | xargs -P "$jobs" -I{} sh "$0" --rune "$rune" --vm "$vm" --out "$out" --loader "$out/load.rbc" --one {})
if [ -n "$fails" ]; then
  echo "$fails"
  echo "check-units: $(echo "$fails" | wc -l | tr -d ' ') of $n programs fail"
  exit 1
fi
echo "check-units: $n programs, the same whole and in units at -O0, -O1 and -O2, linked from their unit files and loaded"
