#!/bin/sh
# Verify that every build of runedoc (MLton, SML/NJ in 64 and 32 bits,
# Poly/ML and, when built, the one compiled by Rune) writes the same output
# for the same input: the documentation must not depend on who built the
# generator. scripts/check-cross.sh runs this.
#   scripts/check-doc-cross.sh
set -u
cd "$(dirname "$0")/.."
out=tests/out/doc-cross
mkdir -p "$out"
builds="mlton smlnj smlnj32 polyml"
[ -x bin/runedoc-boot ] && builds="$builds boot"
status=0

# run NAME ARG...: every build on these arguments. What they print, what they
# complain about and how they exit must be the same; an input with errors in
# it (the tests of tests/doc have some) makes them all fail alike.
run() {
  name=$1
  shift
  for c in $builds; do
    "bin/runedoc-$c" "$@" > "$out/$name.$c.out" 2> "$out/$name.$c.err"
    echo "exit status $?" >> "$out/$name.$c.err"
  done
  [ -s "$out/$name.mlton.out" ] || { echo "FAIL doc-cross $name: runedoc-mlton printed nothing: $(head -1 "$out/$name.mlton.err")"; status=1; }
  for c in $builds; do
    cmp -s "$out/$name.mlton.out" "$out/$name.$c.out" && cmp -s "$out/$name.mlton.err" "$out/$name.$c.err" ||
      { echo "FAIL doc-cross $name: the mlton and $c builds differ (diff $out/$name.mlton.err $out/$name.$c.err)"; status=1; }
  done
}

# shellcheck disable=SC2046
run ir-basis --dump-ir $(grep -l '^signature ' lib/basis/*.sml)
run ir-tests --dump-ir tests/doc/*.sml

# The documentation of the basis library, from every build.
for c in $builds; do
  rm -rf "$out/site.$c"
  "bin/runedoc-$c" --lib lib --library basis --out "$out/site.$c" --title Basis > /dev/null 2> "$out/site.$c.err" ||
    { echo "FAIL doc-cross site: runedoc-$c failed: $(head -1 "$out/site.$c.err")"; status=1; }
done
for c in $builds; do
  diff -r "$out/site.mlton" "$out/site.$c" > /dev/null && cmp -s "$out/site.mlton.err" "$out/site.$c.err" ||
    { echo "FAIL doc-cross site: the mlton and $c builds write different documentation (diff -r $out/site.mlton $out/site.$c)"; status=1; }
done

[ $status = 0 ] && echo "check-doc-cross: the builds of runedoc agree ($builds)"
exit $status
