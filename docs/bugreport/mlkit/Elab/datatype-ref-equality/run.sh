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
out=${TMPDIR:-/tmp}/mlkit-ref-equality
rm -rf "$out"
"$MLKIT" --version 2>&1 | head -1
for prog in bug bug-array bug-functor ok-bare-ref ok-int-ref; do
  dir=$out/$prog
  mkdir -p "$dir"
  cp "$prog.sml" "$dir"
  printf '$(SML_LIB)/basis/basis.mlb\n%s.sml\n' "$prog" > "$dir/prog.mlb"
  if (cd "$dir" && "$MLKIT" --no_messages -o prog prog.mlb > log 2>&1); then
    result=$("$dir/prog" 2>&1 | head -1)
  else
    result="compiler: $(grep -m 1 -A 2 '^Type clash' "$dir/log" | tr -s ' \n' ' ')"
  fi
  printf '%-12s %s\n' "$prog" "$result"
done
