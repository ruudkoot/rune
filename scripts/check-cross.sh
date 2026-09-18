#!/bin/sh
# Verify that the MLton, SML/NJ, Poly/ML and (when built) self-hosted builds
# of the compiler produce byte-identical bytecode for every test program, the
# examples, and the compiler itself.
set -u
cd "$(dirname "$0")/.."
out=tests/out/cross
mkdir -p "$out"
builds="mlton smlnj polyml"
[ -x bin/rune-boot ] && builds="$builds boot"
status=0
count=0

# check NAME SOURCE... : compile the sources with every build and compare.
check() {
  name=$1
  shift
  ok=1
  for c in $builds; do
    if ! "bin/rune-$c" "$@" -o "$out/$name.$c.rbc" 2> "$out/$name.$c.err"; then
      echo "FAIL $name: rune-$c failed: $(head -1 "$out/$name.$c.err")"
      ok=0
    fi
  done
  [ $ok = 1 ] || { status=1; return; }
  for c in $builds; do
    if ! cmp -s "$out/$name.mlton.rbc" "$out/$name.$c.rbc"; then
      echo "FAIL $name: bytecode differs between the mlton and $c builds"
      status=1
      return
    fi
  done
  count=$((count + 1))
}

for src in tests/lang/*.sml examples/*.sml; do
  [ -f "$src" ] || continue
  check "$(basename "$src" .sml)" "$src"
done
# shellcheck disable=SC2046
check rune build/config.sml $(grep -v '^[[:space:]]*#' sources.txt | grep -v '^[[:space:]]*$') src/main/rune-main.sml

echo "check-cross: $count programs produce identical bytecode with all builds ($builds)"
exit $status
