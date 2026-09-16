#!/bin/sh
set -eu
. ./scripts/tools.sh
sml=$(find_sml)
printf 'SML/NJ launcher: %s\n' "$sml"
printf '%s\n' 'val () = print ("Rune doctor: SML/NJ is running\n"); OS.Process.exit OS.Process.success;' | "$sml"
command -v "${ML_BUILD:-ml-build}"
"${POLY:-poly}" --version
"${MLTON:-mlton}" 2>&1 || test "$?" = 1
mosml_paths=$(sh ./scripts/build_mosml.sh)
printf 'Moscow ML runtime: %s\n' "$(printf '%s\n' "$mosml_paths" | sed -n '1p')"
"${CC:-cc}" --version
printf '%s\n' 'Poly/ML uses saved states; no native export library is required.' 'Moscow ML is downloaded and bootstrapped under build/tools using its C runtime and checked-in bootstrap compiler.' 'Run make test-builds to check build failures, spaces in paths, and incremental builds.'
