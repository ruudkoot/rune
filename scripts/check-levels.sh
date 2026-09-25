#!/bin/sh
# Every program of tests/lang and tests/perf compiled at -O0, at -O2, and
# at -O2 with no optional pass (--passes=, the back end alone), the lint of
# every pass on and Mid's text checked against itself (--mid-roundtrip;
# docs/ir.md). All three are run as tests/run-tests.sh runs the program --
# its .args, .stdin and .vmargs -- and must print the same, on both streams,
# and exit the same; and the back end alone must allocate the bytes and
# objects -O0's code does (runevm --count), the cheap check of a back end
# (docs/plans/middle-end.md, M2, M4 and M7): -O0 is Codegen's code, and the
# optimisations of -O2 may allocate less. A program that allocates
# otherwise for a reason is listed, with the reason, in
# scripts/check-levels.alloc.
#   scripts/check-levels.sh [--rune BIN] [--vm BIN] [-j N]
set -u
cd "$(dirname "$0")/.."
rune=bin/rune
vm=bin/runevm
jobs=$(sh scripts/ncpus.sh)
one=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    *) echo "usage: scripts/check-levels.sh [--rune BIN] [--vm BIN] [-j N]" >&2; exit 2 ;;
  esac
done
out=tests/out/levels
mkdir -p "$out"

# --one BASE: one program, BASE without .sml; prints a line when it fails
if [ -n "$one" ]; then
  name=$(echo "$one" | tr '/' '_')
  for level in 0 2 b; do
    case $level in b) flags="-O2 --passes=" ;; *) flags=-O$level ;; esac
    # shellcheck disable=SC2086
    if ! "$rune" $flags --lint --mid-roundtrip "$one.sml" -o "$out/$name.O$level.rbc" 2> "$out/$name.O$level.cerr"; then
      echo "FAIL levels.$name: $flags: $(grep -m1 . "$out/$name.O$level.cerr")"; exit 0
    fi
  done
  args=""; [ -f "$one.args" ] && args=$(cat "$one.args")
  vmargs=""; [ -f "$one.vmargs" ] && vmargs=$(cat "$one.vmargs")
  stdin=/dev/null; [ -f "$one.stdin" ] && stdin=$one.stdin
  for level in 0 2 b; do
    # shellcheck disable=SC2086
    "$vm" --count $vmargs "$out/$name.O$level.rbc" $args < "$stdin" > "$out/$name.O$level.out" 2> "$out/$name.O$level.all"
    echo $? > "$out/$name.O$level.code"
    grep -v '^runevm: count: ' "$out/$name.O$level.all" > "$out/$name.O$level.err"
    sed -n 's/^runevm: count: [0-9]* instructions, //p' "$out/$name.O$level.all" > "$out/$name.O$level.alloc"
  done
  for part in out err code; do
    for level in 2 b; do
      if ! cmp -s "$out/$name.O0.$part" "$out/$name.O$level.$part"; then
        echo "FAIL levels.$name: -O0 and -O$level differ ($part: diff $out/$name.O0.$part $out/$name.O$level.$part)"; exit 0
      fi
    done
  done
  if ! grep -q "^$(basename "$one") " scripts/check-levels.alloc && ! cmp -s "$out/$name.O0.alloc" "$out/$name.Ob.alloc"; then
    echo "FAIL levels.$name: the back end allocates otherwise than -O0 (diff $out/$name.O0.alloc $out/$name.Ob.alloc)"; exit 0
  fi
  exit 0
fi

progs=$(ls tests/lang/*.sml tests/perf/*.sml | sed 's/\.sml$//')
n=$(echo "$progs" | wc -l | tr -d ' ')
fails=$(echo "$progs" | xargs -P "$jobs" -I{} sh "$0" --rune "$rune" --vm "$vm" --one {})
if [ -n "$fails" ]; then
  echo "$fails"
  echo "check-levels: $(echo "$fails" | wc -l | tr -d ' ') of $n programs fail"
  exit 1
fi
echo "check-levels: $n programs, the same at -O0, -O2 and with the back end alone"
