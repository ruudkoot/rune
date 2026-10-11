#!/bin/sh
# The rendering of diagnostics (docs/diagnostics.md). Each NAME.sml is
# compiled by bin/rune --color=always --diagnostics=full, and its standard
# error, with each ESC written \e, must be NAME.expected, which was read
# line by line. Without the styles it must be what --color=never gives, and
# its first lines what the compiler prints into a pipe when not asked for
# more. Where NAME.json.expected is there, the file --diagnostics-json
# writes must be it, with the compiler's version written VERSION.
#   tests/diagnostics/run.sh [--rune BIN] [--update] [FILTER]
set -u
# The renderings must not depend on colour chosen from outside.
unset FORCE_COLOR CLICOLOR_FORCE NO_COLOR CLICOLOR RUNE_COLORS COLORFGBG
cd "$(dirname "$0")/../.."
rune=bin/rune
update=0
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    --update) update=1; shift ;;
    *) filter=$1; shift ;;
  esac
done
out=tests/out/diagnostics
mkdir -p "$out"
esc=$(printf '\033')
passed=0
failed=0
fail() { echo "FAIL $1"; failed=$((failed + 1)); }
for src in tests/diagnostics/*.sml; do
  name=$(basename "$src" .sml)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  base=tests/diagnostics/$name
  o=$out/$name
  "$rune" --color=always --diagnostics=full "$src" -o "$o.rbc" 2> "$o.color"
  sed "s/$esc/\\\\e/g" "$o.color" > "$o.shown"
  "$rune" --color=never --diagnostics=full "$src" -o "$o.rbc" 2> "$o.plain"
  "$rune" "$src" -o "$o.rbc" 2> "$o.short"
  if [ -f "$base.json.expected" ] || [ "$update" = 1 ]; then
    "$rune" --diagnostics-json "$o.json" "$src" -o "$o.rbc" 2> /dev/null
    sed 's/"compilerVersion":"[^"]*"/"compilerVersion":"VERSION"/' "$o.json" > "$o.json.shown"
  fi
  if [ "$update" = 1 ]; then
    cp "$o.shown" "$base.expected"
    [ -f "$base.json.expected" ] && cp "$o.json.shown" "$base.json.expected"
    echo "updated $name"
    continue
  fi
  ok=1
  if ! cmp -s "$o.shown" "$base.expected"; then
    fail "$name: the rendering differs from $base.expected"; diff "$base.expected" "$o.shown" | head -20; ok=0
  fi
  sed "s/$esc\[[0-9;]*m//g" "$o.color" > "$o.unstyled"
  if ! cmp -s "$o.unstyled" "$o.plain"; then
    fail "$name: without its styles it is not what --color=never gives"; ok=0
  fi
  grep "^$src:" "$o.plain" > "$o.first"
  if ! cmp -s "$o.first" "$o.short"; then
    fail "$name: its first lines are not what a pipe gets"; diff "$o.short" "$o.first" | head; ok=0
  fi
  if [ -f "$base.json.expected" ] && ! cmp -s "$o.json.shown" "$base.json.expected"; then
    fail "$name: the JSON differs from $base.json.expected"; ok=0
  fi
  if [ "$ok" = 1 ]; then passed=$((passed + 1)); fi
done
echo "diagnostics: passed $passed, failed $failed"
[ "$failed" = 0 ]
