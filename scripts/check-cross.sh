#!/bin/sh
# Verify that the MLton, SML/NJ and Poly/ML builds of the compiler produce
# byte-identical bytecode for every test program and the basis library.
set -u
cd "$(dirname "$0")/.."
out=tests/out/cross
mkdir -p "$out"
status=0
count=0
for src in tests/lang/*.sml examples/*.sml; do
  [ -f "$src" ] || continue
  name=$(basename "$src" .sml)
  ok=1
  for c in mlton smlnj polyml; do
    if ! "bin/rune-$c" "$src" -o "$out/$name.$c.rbc" 2> "$out/$name.$c.err"; then
      echo "FAIL $name: rune-$c failed: $(head -1 "$out/$name.$c.err")"
      ok=0
    fi
  done
  [ $ok = 1 ] || { status=1; continue; }
  if cmp -s "$out/$name.mlton.rbc" "$out/$name.smlnj.rbc" && cmp -s "$out/$name.mlton.rbc" "$out/$name.polyml.rbc"; then
    count=$((count + 1))
  else
    echo "FAIL $name: bytecode differs between compiler builds"
    status=1
  fi
done
echo "check-cross: $count programs produce identical bytecode with all three builds"
exit $status
