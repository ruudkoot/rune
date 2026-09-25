#!/bin/sh
# Build and run every program three ways: as MLton builds it by default,
# with its SSA type-checked after every pass, and with SplitTypes disabled.
# Each is a standalone program: `mlton prog.sml`, MLton's own Basis Library.
# MLTON names the compiler (default: mlton on the PATH).
MLTON=${MLTON:-mlton}
cd "$(dirname "$0")"
out=${TMPDIR:-/tmp}/mlton-splittypes
mkdir -p "$out"
"$MLTON" 2>&1 | head -1
for prog in bug bug-cons bug-original ok-tabulate ok-literal ok-int-list; do
  for mode in default type-check no-split-types; do
    case $mode in
      default) flags="" ;;
      type-check) flags="-type-check true" ;;
      no-split-types) flags="-disable-pass splitTypes.*" ;;
    esac
    rm -f "$out/$prog"
    # shellcheck disable=SC2086
    msg=$("$MLTON" $flags -output "$out/$prog" "$prog.sml" 2>&1 | head -1)
    if [ -x "$out/$prog" ]; then result=$("$out/$prog" 2>&1 | head -1)
    else result="compiler: $msg"; fi
    printf '%-14s %-15s %s\n' "$prog" "$mode" "$result"
  done
done
