#!/bin/sh
# Rune's library (lib/basis), cut down to the files that FILE... need, in
# OUTDIR/lib: a program that names a structure of Rune's that the host's
# library does not have (INet6Sock, Runtime, ...) then finds none, as it would
# on the host, instead of Rune's.
#   tests/basis/xc2/trim-lib.sh OUTDIR FILE...     (RUNE: bin/rune)
set -eu
out=$1; shift
cd "$(dirname "$0")/../../.."
rune=${RUNE:-bin/rune}
rm -rf "${out:?}/lib"
mkdir -p "$out/lib/basis"
"$rune" --lib lib --allow-prim --basis-deps "$@" > "$out/lib.files"
awk 'NR == FNR { keep[$0] = 1; next } /^#/ || /^[ \t]*$/ || ($1 in keep)' \
  "$out/lib.files" lib/basis/MANIFEST > "$out/lib/basis/MANIFEST"
while read -r f; do cp "lib/basis/$f" "$out/lib/basis/$f"; done < "$out/lib.files"
