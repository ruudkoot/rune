#!/bin/sh
# The first rewrite of the optimiser that breaks a program (docs/ir.md,
# after Whalley, "Automatic isolation of compiler errors"): compiled with
# --fuel=N a program makes only the first N rewrites, so it runs as at -O0
# with no fuel and as at -O2 with enough; halving N between the two finds
# the rewrite after which what it prints, on both streams, or how it exits,
# is no longer what it is at -O0. --dump-after=all with --fuel=N-1 and
# --fuel=N then shows that rewrite.
#   scripts/bisect-fuel.sh [--rune BIN] [--vm BIN] PROGRAM.sml [ARGS ...]
set -u
cd "$(dirname "$0")/.."
rune=bin/rune
vm=bin/runevm
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || { echo "usage: scripts/bisect-fuel.sh [--rune BIN] [--vm BIN] PROGRAM.sml [ARGS ...]" >&2; exit 2; }
prog=$1; shift
progargs="$*"
out=tests/out/bisect
mkdir -p "$out"

# run LABEL OPTIONS...: compile with the options and run; the outcome is in
# $out/LABEL.all (the two streams and the exit status)
run() {
  label=$1; shift
  if ! "$rune" "$@" "$prog" -o "$out/$label.rbc" 2> "$out/$label.cerr"; then
    echo "compile error" > "$out/$label.all"; cat "$out/$label.cerr" >> "$out/$label.all"; return
  fi
  # shellcheck disable=SC2086
  "$vm" "$out/$label.rbc" $progargs > "$out/$label.out" 2> "$out/$label.err" < /dev/null
  code=$?
  { cat "$out/$label.out"; echo "--- stderr"; cat "$out/$label.err"; echo "--- exit $code"; } > "$out/$label.all"
}
# breaks N: whether --fuel=N gives another outcome than -O0
breaks() { run fuel -O2 --fuel="$1"; ! cmp -s "$out/fuel.all" "$out/reference.all"; }

run reference -O0
run full -O2
if cmp -s "$out/full.all" "$out/reference.all"; then echo "bisect-fuel: $prog runs the same at -O2 as at -O0"; exit 0; fi
if breaks 0; then echo "bisect-fuel: $prog differs even with no rewrite: not a rewrite of the optimiser"; exit 1; fi
hi=1
while ! breaks $hi; do
  if [ $hi -ge 1073741824 ]; then echo "bisect-fuel: no fuel breaks $prog, only -O2 does"; exit 1; fi
  hi=$((hi * 2))
done
lo=$((hi / 2))
# lo does not break, hi does
while [ $((hi - lo)) -gt 1 ]; do
  mid=$(((lo + hi) / 2))
  if breaks $mid; then hi=$mid; else lo=$mid; fi
done
echo "bisect-fuel: rewrite $hi breaks $prog; compare"
echo "  $rune -O2 --fuel=$lo --dump-after=all $prog"
echo "  $rune -O2 --fuel=$hi --dump-after=all $prog"
exit 1
