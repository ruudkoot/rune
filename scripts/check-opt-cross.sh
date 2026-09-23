#!/bin/sh
# Verify that every build of runeopt (MLton, SML/NJ in 64 and 32 bits,
# Poly/ML and, when built, the one compiled by Rune) says the same of the same
# programs: what the native code generator makes of a program must not depend
# on who built it (docs/plans/codegen.md). scripts/check-cross.sh runs this.
#   scripts/check-opt-cross.sh
set -u
cd "$(dirname "$0")/.."
out=tests/out/opt-cross
mkdir -p "$out"
builds="mlton smlnj smlnj32 polyml"
[ -x bin/runeopt-boot ] && builds="$builds boot"
status=0

# run NAME ARG...: every build on these arguments. What they print, what they
# complain about and how they exit must be the same.
run() {
  name=$1
  shift
  for c in $builds; do
    "bin/runeopt-$c" "$@" > "$out/$name.$c.out" 2> "$out/$name.$c.err"
    echo "exit status $?" >> "$out/$name.$c.err"
  done
  for c in $builds; do
    cmp -s "$out/$name.mlton.out" "$out/$name.$c.out" && cmp -s "$out/$name.mlton.err" "$out/$name.$c.err" ||
      { echo "FAIL opt-cross $name: the mlton and $c builds differ (diff $out/$name.mlton.out $out/$name.$c.out)"; status=1; }
  done
}

run facts --facts bin/rune.rbc bin/runedoc.rbc
run disasm-rune --disasm bin/rune.rbc
# a file the loader refuses
printf 'RUNE\002\000\000\000\001\000\000\000\003\360\377\377\377' > "$out/bad.rbc"
run refused --check "$out/bad.rbc"

[ $status = 0 ] && echo "check-opt-cross: the builds of runeopt agree ($builds)"
exit $status
