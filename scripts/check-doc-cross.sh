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

# run NAME ARG...: the output of every build on these arguments.
run() {
  name=$1
  shift
  for c in $builds; do
    "bin/runedoc-$c" "$@" > "$out/$name.$c.out" 2> "$out/$name.$c.err" ||
      { echo "FAIL doc-cross $name: runedoc-$c failed: $(head -1 "$out/$name.$c.err")"; status=1; }
  done
  for c in $builds; do
    cmp -s "$out/$name.mlton.out" "$out/$name.$c.out" && cmp -s "$out/$name.mlton.err" "$out/$name.$c.err" ||
      { echo "FAIL doc-cross $name: the output differs between the mlton and $c builds"; status=1; }
  done
}

# shellcheck disable=SC2046
run signatures $(grep -l '^signature ' lib/basis/*.sml)

[ $status = 0 ] && echo "check-doc-cross: the builds of runedoc agree ($builds)"
exit $status
