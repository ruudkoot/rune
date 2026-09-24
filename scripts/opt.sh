#!/bin/sh
# An executable from SML sources, for trying runeopt out: the sources are
# compiled by bin/rune and the bytecode translated by bin/runeopt
# (docs/plans/codegen.md). Not installed.
#   scripts/opt.sh [-o EXE] FILE.sml ...
# EXE defaults to the first file without .sml; its bytecode is kept beside it
# as EXE.rbc. RUNE and RUNEOPT choose other builds (RUNEOPT=bin/runeopt-mlton
# is the faster one).
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
rune=${RUNE:-$root/bin/rune}
runeopt=${RUNEOPT:-$root/bin/runeopt}
exe=""
if [ "${1:-}" = -o ]; then exe=$2; shift 2; fi
[ $# -gt 0 ] || { echo "usage: scripts/opt.sh [-o EXE] FILE.sml ..." >&2; exit 2; }
[ -n "$exe" ] || exe=${1%.sml}
"$rune" "$@" -o "$exe.rbc"
"$runeopt" "$exe.rbc" -o "$exe"
