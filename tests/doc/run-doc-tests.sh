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
# Every directory tests/doc/NAME.lib is a small library (a MANIFEST, perhaps a
# DOCUMENTED). Its documentation is generated into tests/out/doc/NAME.site:
#   NAME.lib.diag   the diagnostics of `runedoc --lib tests/doc --library NAME.lib`
#   NAME.lib.files  the files it writes, one on a line (none after an error)
#   NAME.lib.labels for a library with a suite in NAME.lib/tests: the checks
#                   that `runedoc --tests NAME.lib/tests --labels` finds
#   NAME.lib.cover  and what `--check-coverage` says about them
#   NAME.lib.notes  the notes.tsv it writes, where the expectation exists
#   NAME.lib.md     the pages of its signatures, one after another, where the
#                   expectation exists
# A library with a suite is generated with --tests, so that pins are checked,
# and one with a file ANNOTATIONS with --annotations.
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

for lib in tests/doc/*.lib; do
  [ -d "$lib" ] || continue
  name=$(basename "$lib" .lib)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  rm -rf "$out/$name.site"
  suite=""
  [ -d "$lib/tests" ] && suite="--tests $lib/tests"
  [ -f "$lib/ANNOTATIONS" ] && suite="$suite --annotations $lib/ANNOTATIONS"
  # shellcheck disable=SC2086
  "$runedoc" --lib tests/doc --library "$name.lib" $suite --out "$out/$name.site" --title "$name" > /dev/null 2> "$out/$name.lib.diag"
  if [ -d "$out/$name.site" ]; then (cd "$out/$name.site" && find . -type f | sort) > "$out/$name.lib.files"; else : > "$out/$name.lib.files"; fi
  if [ $update = 1 ]; then
    cp "$out/$name.lib.diag" "tests/doc/$name.lib.diag"
    cp "$out/$name.lib.files" "tests/doc/$name.lib.files"
  fi
  same "$name.lib.diag" "$out/$name.lib.diag" "tests/doc/$name.lib.diag"
  same "$name.lib.files" "$out/$name.lib.files" "tests/doc/$name.lib.files"
  if [ -f "tests/doc/$name.lib.notes" ]; then
    cp "$out/$name.site/notes.tsv" "$out/$name.lib.notes" 2> /dev/null || : > "$out/$name.lib.notes"
    [ $update = 1 ] && cp "$out/$name.lib.notes" "tests/doc/$name.lib.notes"
    same "$name.lib.notes" "$out/$name.lib.notes" "tests/doc/$name.lib.notes"
  fi
  if [ -f "tests/doc/$name.lib.md" ]; then
    cat "$out/$name.site"/sig/*.md > "$out/$name.lib.md" 2> /dev/null || : > "$out/$name.lib.md"
    [ $update = 1 ] && cp "$out/$name.lib.md" "tests/doc/$name.lib.md"
    same "$name.lib.md" "$out/$name.lib.md" "tests/doc/$name.lib.md"
  fi
  if [ -d "$lib/tests" ]; then
    "$runedoc" --tests "$lib/tests" --labels > "$out/$name.lib.labels" 2>&1
    "$runedoc" --lib tests/doc --library "$name.lib" --tests "$lib/tests" --check-coverage > "$out/$name.lib.cover" 2>&1
    if [ $update = 1 ]; then
      cp "$out/$name.lib.labels" "tests/doc/$name.lib.labels"
      cp "$out/$name.lib.cover" "tests/doc/$name.lib.cover"
    fi
    same "$name.lib.labels" "$out/$name.lib.labels" "tests/doc/$name.lib.labels"
    same "$name.lib.cover" "$out/$name.lib.cover" "tests/doc/$name.lib.cover"
  fi
done

echo "test-doc: passed $passed, failed $failed"
[ $failed = 0 ]
