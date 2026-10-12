#!/bin/sh
# What a file of expectations skips (docs/testing.md, Expectations; the
# engine is lib/test/runner's Expectations, and this is its reading for the
# shell runners): one line for each test it leaves out, its path, or with
# --reasons its path, a space and its reason.
#   sh tests/skipped.sh [--reasons] FILE [WAY]
# A line is `WAY-GLOB | PATH | CATEGORY | reason`; the skips are the lines
# whose category means skip (HOST-ABSENT, XC1-NA, XC2-NA, UNTESTED,
# UNSUPPORTED), in the way WAY, or in every way when no WAY is given.
set -uf
reasons=0
[ "${1:-}" = --reasons ] && { reasons=1; shift; }
file=$1
way=${2:-}
[ -f "$file" ] || exit 0
sed -e 's/#.*//' "$file" | while IFS='|' read -r w p c r; do
  w=$(echo $w); p=$(echo $p); c=$(echo $c); r=$(echo $r)
  [ -n "$p" ] || continue
  case $c in HOST-ABSENT|XC1-NA|XC2-NA|UNTESTED|UNSUPPORTED) ;; *) continue ;; esac
  if [ -n "$way" ]; then
    # shellcheck disable=SC2254
    case $way in $w) ;; *) continue ;; esac
  fi
  if [ "$reasons" = 1 ]; then echo "$p $r"; else echo "$p"; fi
done
