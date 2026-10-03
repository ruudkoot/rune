#!/bin/sh
# The compiler, translated by runeopt, compiles itself to bin/rune.stack.rbc:
# what make bootstrap is for the compiler on runevm, for native code
# (docs/native.md, Tests). RUNEOPT chooses the build of runeopt,
# RUNE_HEAP the heap the compiler starts with, as bin/rune-boot gives it.
#   tests/opt/run-bootstrap.sh
set -u
cd "$(dirname "$0")/../.."
out=tests/out/opt-bootstrap
mkdir -p "$out"
runeopt=${RUNEOPT:-bin/runeopt-mlton}
"$runeopt" bin/rune.stack.rbc -o "$out/rune" --options "--heap-size ${RUNE_HEAP:-67108864}" ||
  { echo "FAIL opt-bootstrap: runeopt could not translate bin/rune.stack.rbc"; exit 1; }
srcs="build/config.sml $(grep -v '^[[:space:]]*#' sources.txt | grep -v '^[[:space:]]*$' | tr '\n' ' ') src/main/rune-main.sml"
# shellcheck disable=SC2086
"$out/rune" --target=stack --lib bin/../lib -o "$out/rune.stage2.rbc" $srcs ||
  { echo "FAIL opt-bootstrap: the compiler as native code failed"; exit 1; }
cmp bin/rune.stack.rbc "$out/rune.stage2.rbc" ||
  { echo "FAIL opt-bootstrap: the compiler as native code does not reproduce bin/rune.stack.rbc"; exit 1; }
echo "opt-bootstrap: the compiler as native code reproduces bin/rune.stack.rbc"
