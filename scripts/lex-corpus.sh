#!/bin/sh
# Lex corpora in every source mode (docs/plans/utf8.md, M3; its experiment
# E9): which files each mode refuses, and what lexing them costs.
#
#   scripts/lex-corpus.sh [--rune DIR] [--out DIR] [--modes LIST] [--cost K] [--against DIR] [-j N] CORPUS...
#
# A CORPUS is rune, this tree's tracked sources; NAME=DIR, the .sml, .sig
# and .fun files under DIR; or NAME=@LIST, the files LIST names, one a line.
# Each file is lexed by itself (rune --lex-count 1) in each mode of LIST, a
# comma-separated list of (default: all three)
#   default   no flag
#   unicode   --unicode
#   latin1    --unicode=latin1
# and OUT/NAME.MODE.refused lists the files refused, each with the first
# line of its error. One line a corpus and mode is printed: how many of its
# files lex. With --cost K, the line also has the instructions to lex, once,
# the files that every mode of LIST takes: runevm --count over them lexed
# once and 1+K times, the difference over K, so that starting the compiler
# is not counted. With --against DIR as well, the same files are counted by
# the compiler of DIR too, in the default mode, and the change from that is
# printed: the cost of a lexer against another's. The files are then also
# those that DIR's compiler takes. The DIR of --rune
# (default: this tree) and of --against is a built tree whose bin/rune.rbc
# takes --lex-count; a tree without --unicode is measured with --modes
# default.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
tree=$root
out=$root/tests/out/lex-corpus
modes=default,unicode,latin1
cost=0
against=""
jobs=$(sh "$root/scripts/ncpus.sh" 2>/dev/null || echo 4)
usage() { echo "usage: scripts/lex-corpus.sh [--rune DIR] [--out DIR] [--modes LIST] [--cost K] [--against DIR] [-j N] CORPUS..." >&2; exit 2; }
while [ $# -gt 0 ]; do
  case $1 in
    --rune) tree=$(cd "$2" && pwd) || exit 2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --modes) modes=$2; shift 2 ;;
    --cost) cost=$2; shift 2 ;;
    --against) against=$(cd "$2" && pwd) || exit 2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    -*) usage ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || usage
mkdir -p "$out"
flagsOf() {
  case $1 in
    default) echo "" ;;
    unicode) echo "--unicode" ;;
    latin1) echo "--unicode=latin1" ;;
    *) echo "lex-corpus: no mode $1" >&2; exit 2 ;;
  esac
}
# the instructions of the compiler of TREE to lex the files of LIST under
# FLAGS N times
count() {
  # shellcheck disable=SC2046
  (ulimit -v 8000000
   "$4/bin/runevm" --count --heap-size 268435456 "$4/bin/rune.rbc" --lib "$4/lib" $2 --lex-count "$3" \
     $(cat "$1") 2>&1) | sed -n 's/.*count: \([0-9]*\) instructions.*/\1/p'
}
# the instructions to lex the files of LIST once, by TREE under FLAGS
once() {
  a=$(count "$1" "$2" 1 "$3")
  b=$(count "$1" "$2" $((1 + cost)) "$3")
  if [ -n "$a" ] && [ -n "$b" ]; then echo $(( (b - a) / cost )); else echo failed; fi
}
printf '%-10s %-8s %7s %7s %15s %15s %8s\n' corpus mode lexed files instructions against change
for corpus in "$@"; do
  case $corpus in
    rune) name=rune
          git -C "$root" ls-files '*.sml' '*.sig' '*.fun' | sed "s|^|$root/|" > "$out/$name.files" ;;
    *=@*) name=${corpus%%=*}; list=${corpus#*=@}
          grep -v '^$' "$list" > "$out/$name.files" ;;
    *=*) name=${corpus%%=*}; dir=${corpus#*=}
         find "$dir" -type f \( -name '*.sml' -o -name '*.sig' -o -name '*.fun' \) | LC_ALL=C sort > "$out/$name.files" ;;
    *) usage ;;
  esac
  total=$(wc -l < "$out/$name.files")
  cp "$out/$name.files" "$out/$name.every"
  # the files the compiler of DIR refuses under FLAGS, to
  # OUT/NAME.LABEL.refused and .names, and taken out of those every mode
  # takes: refusing DIR FLAGS LABEL
  refusing() {
    lexer=$1 flags=$2
    export lexer flags
    # shellcheck disable=SC2016
    (ulimit -v 6000000
     tr '\n' '\0' < "$out/$name.files" | xargs -0 -P "$jobs" -I{} sh -c '
       r=$("$lexer/bin/rune" $flags --lex-count 1 "$1" 2>&1 > /dev/null | head -1)
       if [ -n "$r" ]; then printf "%s\t%s\n" "$1" "$r"; fi' sh {}) | LC_ALL=C sort > "$out/$name.$3.refused"
    cut -f1 "$out/$name.$3.refused" > "$out/$name.$3.names"
    LC_ALL=C sort "$out/$name.every" | LC_ALL=C comm -23 - "$out/$name.$3.names" > "$out/$name.every.new"
    mv "$out/$name.every.new" "$out/$name.every"
  }
  for mode in $(echo "$modes" | tr ',' ' '); do
    refusing "$tree" "$(flagsOf "$mode")" "$mode"
    refused=$(wc -l < "$out/$name.$mode.refused")
    eval "lexed_$mode=$((total - refused))"
  done
  if [ "$cost" -gt 0 ] && [ -n "$against" ]; then refusing "$against" "" against; fi
  base=""
  if [ "$cost" -gt 0 ] && [ -n "$against" ] && [ -s "$out/$name.every" ]; then base=$(once "$out/$name.every" "" "$against"); fi
  for mode in $(echo "$modes" | tr ',' ' '); do
    eval "lexed=\$lexed_$mode"
    instr=""
    change=""
    if [ "$cost" -gt 0 ] && [ -s "$out/$name.every" ]; then
      instr=$(once "$out/$name.every" "$(flagsOf "$mode")" "$tree")
      case "$instr$base" in
        *failed*|"$instr"|"${instr}0") ;;
        *) change=$(awk -v a="$instr" -v b="$base" 'BEGIN { printf "%+.1f%%", (a - b) * 100 / b }') ;;
      esac
    fi
    printf '%-10s %-8s %7s %7s %15s %15s %8s\n' "$name" "$mode" "$lexed" "$total" "$instr" "$base" "$change"
  done
done
