#!/bin/sh
# Build and run every program. Each uses MLKit's own Basis Library only,
# through an .mlb file. MLKIT names the compiler (default: mlkit on the
# PATH) and SML_LIB its library (default: lib/mlkit next to its bin/).
# MLKit writes what it compiles next to the sources, so every build copies
# its program into a directory of its own under $TMPDIR.
MLKIT=${MLKIT:-mlkit}
MLKIT=$(command -v "$MLKIT")
SML_LIB=${SML_LIB:-$(dirname "$(dirname "$MLKIT")")/lib/mlkit}
export SML_LIB
cd "$(dirname "$0")"
out=${TMPDIR:-/tmp}/mlkit-tab-in-string
rm -rf "$out"
"$MLKIT" --version 2>&1 | head -1
for prog in bug bug-columns bug-char bug-char-length related-controls \
            ok-escape ok-gap; do
  dir=$out/$prog
  mkdir -p "$dir"
  cp "$prog.sml" "$dir"
  printf '$(SML_LIB)/basis/basis.mlb\n%s.sml\n' "$prog" > "$dir/prog.mlb"
  if (cd "$dir" && "$MLKIT" --no_messages -o prog prog.mlb > log 2>&1); then
    "$dir/prog" 2>&1
  else
    # The message is the first line that is not a position, a line of the
    # source or its underlining.
    echo "compiler: $(grep -v -e ', line [0-9]*, column [0-9]*:' -e '^ ' \
                           -e '^Stopping' -e '^$' "$dir/log" | head -1)"
  fi | sed "1s/^/$(printf '%-17s' "$prog")/; 2,\$s/^/                 /"
done
