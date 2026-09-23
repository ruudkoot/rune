#!/bin/sh
# Every instruction comes from a line that exists (docs/plans/runtime.md, M5):
#   sh scripts/check-positions.sh [-j N] [--rune BIN] [--vm BIN] [FILTER]
#
# The loader refuses a line table whose pc or file index is out of range, so
# what is checked here is what it cannot see: that every position names one of
# the files the program was compiled from, and a line that file really has. A
# wrong position is invisible otherwise -- the program still runs -- which is
# why it is checked over every program rather than a few.
set -u
rune=bin/rune
vm=bin/runevm
jobs=
filter=

if [ "${1:-}" = "--one" ]; then
  rune=$2 vm=$3 out=$4 src=$5
  name=$(basename "$src" .sml)
  "$rune" --lib lib "$src" -o "$out/$name.rbc" > "$out/$name.log" 2>&1 || exit 0
  "$vm" --disasm "$out/$name.rbc" 2>/dev/null |
    sed -n 's/.*	; \(.*\)$/\1/p' |
    awk -F: '{ if ($2 + 0 < 1) low[$1] = 1; if ($2 + 0 > hi[$1]) hi[$1] = $2 + 0 }
             END { for (f in hi) print f, hi[f], (f in low) ? "low" : "ok" }' |
    while read -r file top low; do
      if [ ! -f "$file" ]; then
        echo "$name: a position names $file, which is not a file"
      elif [ "$low" = low ]; then
        echo "$name: a position in $file is before its first line"
      elif [ "$top" -gt "$(wc -l < "$file")" ]; then
        echo "$name: $file has no line $top"
      fi
    done
  exit 0
fi

while [ $# -gt 0 ]; do
  case $1 in
    -j) jobs=$2; shift 2 ;;
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    *) filter=$1; shift ;;
  esac
done
cd "$(dirname "$0")/.."
[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh)
out=tests/out/positions
rm -rf "$out"; mkdir -p "$out"

sources=""
for src in tests/lang/*.sml examples/*.sml; do
  case "$src" in *"$filter"*) [ -f "$src" ] && sources="$sources $src" ;; esac
done

# shellcheck disable=SC2086
printf '%s\n' $sources |
  xargs -P "$jobs" -I{} sh scripts/check-positions.sh --one "$rune" "$vm" "$out" {} > "$out/bad"

if [ -s "$out/bad" ]; then
  cat "$out/bad" >&2
  echo "check-positions: $(wc -l < "$out/bad" | tr -d ' ') positions name a line that does not exist" >&2
  exit 1
fi
echo "check-positions: every instruction of $(printf '%s\n' $sources | wc -l | tr -d ' ') programs comes from a line that exists"
