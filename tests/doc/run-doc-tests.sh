#!/bin/sh
# The tests of the documentation generator (docs/plans/docgen.md, D11).
#   tests/doc/run-doc-tests.sh [--update] [FILTER]
# Every tests/doc/NAME.sml is an input. What runedoc makes of it is compared
# with the expectations next to it, each of which is optional:
#   NAME.ir    the output of `runedoc --dump-ir tests/doc/NAME.sml`
# --update rewrites the expectations that exist; review them line by line as
# you would an .expected file. Override the generator with RUNEDOC=.
set -u
update=0
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    --update) update=1; shift ;;
    -*) echo "usage: tests/doc/run-doc-tests.sh [--update] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
cd "$(dirname "$0")/../.."
runedoc=${RUNEDOC:-bin/runedoc}
out=tests/out/doc
mkdir -p "$out"
passed=0
failed=0

# expect NAME EXT COMMAND...: the output of the command against NAME.EXT
expect() {
  name=$1 ext=$2
  shift 2
  [ -f "tests/doc/$name.$ext" ] || return 0
  "$@" > "$out/$name.$ext" 2> "$out/$name.$ext.err"
  if [ $update = 1 ]; then
    cp "$out/$name.$ext" "tests/doc/$name.$ext"
  fi
  if cmp -s "$out/$name.$ext" "tests/doc/$name.$ext" && [ ! -s "$out/$name.$ext.err" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "failed: $name.$ext (diff tests/doc/$name.$ext $out/$name.$ext; $out/$name.$ext.err)"
  fi
}

for src in tests/doc/*.sml; do
  name=$(basename "$src" .sml)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  expect "$name" ir "$runedoc" --dump-ir "$src"
done

echo "test-doc: passed $passed, failed $failed"
[ $failed = 0 ]
