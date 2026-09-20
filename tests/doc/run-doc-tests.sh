#!/bin/sh
# The tests of the documentation generator (docs/plans/docgen.md, D11).
#   tests/doc/run-doc-tests.sh [--update] [FILTER]
# Every tests/doc/NAME.sml is an input. What runedoc makes of it is compared
# with the expectations next to it:
#   NAME.ir    the output of `runedoc --dump-ir tests/doc/NAME.sml`
#   NAME.diag  the diagnostics of that run (its standard error); a test
#              without this file must produce none
#   NAME.md    the output of `runedoc --page tests/doc/NAME.sml`: the pages of
#              the signatures of the file
#   NAME.md.diag  the diagnostics of that run; without it there must be none
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

# same WHAT GOT WANT: count a comparison
same() {
  if cmp -s "$2" "$3"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "failed: $1 (diff $3 $2)"
  fi
}

for src in tests/doc/*.sml; do
  name=$(basename "$src" .sml)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  if [ -f "tests/doc/$name.ir" ] || [ -f "tests/doc/$name.diag" ]; then
    "$runedoc" --dump-ir "$src" > "$out/$name.ir" 2> "$out/$name.diag"
    if [ $update = 1 ]; then
      [ -f "tests/doc/$name.ir" ] && cp "$out/$name.ir" "tests/doc/$name.ir"
      [ -f "tests/doc/$name.diag" ] && cp "$out/$name.diag" "tests/doc/$name.diag"
    fi
    [ -f "tests/doc/$name.ir" ] && same "$name.ir" "$out/$name.ir" "tests/doc/$name.ir"
    if [ -f "tests/doc/$name.diag" ]; then
      same "$name.diag" "$out/$name.diag" "tests/doc/$name.diag"
    elif [ -s "$out/$name.diag" ]; then
      failed=$((failed + 1))
      echo "failed: $name printed diagnostics and has no .diag: $(head -1 "$out/$name.diag")"
    fi
  fi
  if [ -f "tests/doc/$name.md" ]; then
    "$runedoc" --page "$src" > "$out/$name.md" 2> "$out/$name.md.diag"
    if [ $update = 1 ]; then
      cp "$out/$name.md" "tests/doc/$name.md"
      [ -f "tests/doc/$name.md.diag" ] && cp "$out/$name.md.diag" "tests/doc/$name.md.diag"
    fi
    same "$name.md" "$out/$name.md" "tests/doc/$name.md"
    if [ -f "tests/doc/$name.md.diag" ]; then
      same "$name.md.diag" "$out/$name.md.diag" "tests/doc/$name.md.diag"
    elif [ -s "$out/$name.md.diag" ]; then
      failed=$((failed + 1))
      echo "failed: $name printed diagnostics for its page and has no .md.diag: $(head -1 "$out/$name.md.diag")"
    fi
  fi
done

echo "test-doc: passed $passed, failed $failed"
[ $failed = 0 ]
