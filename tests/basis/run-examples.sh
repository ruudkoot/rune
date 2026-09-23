#!/bin/sh
# Try the examples of the library's documentation (docs/doc-comments.md): an
# `Example:` that is an equation, `e = v`, has to hold.
#   tests/basis/run-examples.sh
# runedoc writes a program for every signature that has such examples into
# tests/out/basis-examples; each is compiled and run with Rune, and prints a
# line PASS or FAIL for every example. `make test-basis` runs this after the
# suite. The examples say what Rune's library does (`Int.precision = SOME 64`),
# so they are not tried on the hosts. Override the tools with RUNEDOC=, RUNE=
# and RUNEVM=.
set -u
cd "$(dirname "$0")/../.."
runedoc=${RUNEDOC:-bin/runedoc}
rune=${RUNE:-bin/rune}
runevm=${RUNEVM:-bin/runevm}
out=tests/out/basis-examples
mkdir -p "$out"

"$runedoc" --lib lib --library basis --examples "$out" > "$out/runedoc.log" 2>&1 ||
  { cat "$out/runedoc.log"; echo "test-examples: runedoc failed"; exit 1; }

programs=0
passed=0
failed=0
for src in "$out"/*.sml; do
  [ -f "$src" ] || continue
  programs=$((programs + 1))
  base=${src%.sml}
  if ! "$rune" -o "$base.rbc" "$src" > "$base.log" 2>&1; then
    failed=$((failed + 1))
    echo "FAIL $(basename "$base"): its examples do not compile: $(head -1 "$base.log")"
    continue
  fi
  "$runevm" "$base.rbc" > "$base.log" 2>&1
  status=$?
  passed=$((passed + $(grep -c '^PASS ' "$base.log")))
  failed=$((failed + $(grep -c '^FAIL ' "$base.log")))
  grep '^FAIL ' "$base.log"
  if [ $status != 0 ] && ! grep -q '^FAIL ' "$base.log"; then
    failed=$((failed + 1))
    echo "FAIL $(basename "$base"): the program ended with status $status: $(tail -1 "$base.log")"
  fi
done

echo "test-examples: $passed examples of $programs signatures hold, $failed do not"
[ $failed = 0 ]
