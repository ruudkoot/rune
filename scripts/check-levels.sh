#!/bin/sh
# Every program of tests/lang and tests/perf compiled at -O0 -- the stages
# with no optional pass -- and at -O2, the lint of every pass on and Mid's
# text checked against itself (--mid-roundtrip; docs/ir.md). Both are run
# --checked (DECON tests its tag), as tests/run-tests.sh runs the program --
# its .args, .stdin and .vmargs, and its .cargs for the compiler -- and must
# print the same, on both streams, traces included, and exit the same: the
# differential check of the optimisations (docs/plans/middle-end.md, M2 and
# M10). Each is built a second time as one program of its units' Mid
# (--units --whole; the incremental roadmap's M7), at both levels, and must
# print the same too.
#   scripts/check-levels.sh [--rune BIN] [--vm BIN] [-j N]
set -u
cd "$(dirname "$0")/.."
rune=bin/rune-stack
vm=bin/runevm-stack
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
  cargs=""; [ -f "$one.cargs" ] && cargs=$(cat "$one.cargs")
  for b in O0 O2 U0 U2; do
    case $b in
      O*) flags="-O${b#O} $cargs" ;;
      U*) flags="--units --whole --no-cache -O${b#U} $cargs" ;;
    esac
    # shellcheck disable=SC2086
    if ! "$rune" $flags --lint --mid-roundtrip "$one.sml" -o "$out/$name.$b.rbc" 2> "$out/$name.$b.cerr"; then
      echo "FAIL levels.$name: $flags: $(grep -m1 . "$out/$name.$b.cerr")"; exit 0
    fi
  done
  args=""; [ -f "$one.args" ] && args=$(cat "$one.args")
  vmargs=""; [ -f "$one.vmargs" ] && vmargs=$(cat "$one.vmargs")
  stdin=/dev/null; [ -f "$one.stdin" ] && stdin=$one.stdin
  for b in O0 O2 U0 U2; do
    # shellcheck disable=SC2086
    "$vm" --checked $vmargs "$out/$name.$b.rbc" $args < "$stdin" > "$out/$name.$b.out" 2> "$out/$name.$b.err"
    echo $? > "$out/$name.$b.code"
  done
  for b in O2 U0 U2; do
    for part in out err code; do
      if ! cmp -s "$out/$name.O0.$part" "$out/$name.$b.$part"; then
        echo "FAIL levels.$name: -O0 and $b differ ($part: diff $out/$name.O0.$part $out/$name.$b.$part)"; exit 0
      fi
    done
  done
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
echo "check-levels: $n programs, the same at -O0 and -O2, whole and made of their units' Mid"
