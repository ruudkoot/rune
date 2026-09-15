#!/bin/sh
set -eu
. ./scripts/tools.sh
sml=$(find_sml)
printf 'SML/NJ launcher: %s\n' "$sml"
printf '%s\n' 'val () = print ("Rune doctor: SML/NJ is running\n"); OS.Process.exit OS.Process.success;' | "$sml"
command -v "${ML_BUILD:-ml-build}"
"${POLY:-poly}" --version
"${MLTON:-mlton}" 2>&1 || test "$?" = 1
"${CC:-cc}" --version
printf '%s\n' 'Poly/ML uses saved states; no native export library is required.' 'Run make test-builds to check build failures, spaces in paths, and incremental builds.'
