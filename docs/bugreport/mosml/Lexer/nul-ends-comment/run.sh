#!/bin/sh
# Compile and run every program with Moscow ML's batch compiler, mosmlc,
# and load it into its toplevel, mosml. MOSMLC names the compiler
# (default: mosmlc on the PATH); mosml is the one in the same directory.
# Each program holds one character 0 (od -c shows it as \0). mosmlc
# writes what it compiles next to the source, so the programs are copied
# to a directory under $TMPDIR first.
MOSMLC=${MOSMLC:-mosmlc}
MOSMLC=$(command -v "$MOSMLC")
MOSML=$(dirname "$MOSMLC")/mosml
out=${TMPDIR:-/tmp}/mosml-nul-ends-comment
rm -rf "$out"
mkdir -p "$out"
cp "$(dirname "$0")"/*.sml "$out"
cd "$out" || exit 1
echo 'quit();' | "$MOSML" -P none | head -1
# What a run shows: the error message if there is one (grep -a, since the
# echoed source line holds the character 0), else the lines printed.
show() {
  if grep -a -q '^! [A-Z]' "$1"; then
    echo "error: $(grep -a '^! [A-Z]' "$1" | tail -1 | cut -c3-)"
  else
    echo "prints: $(awk 'NF { printf "%s%s", sep, $0; sep = " / " }' "$1")"
  fi
}
for prog in bug bug-string bug-between; do
  if "$MOSMLC" -o "$prog" "$prog.sml" > "$prog.mosmlc" 2>&1; then
    "./$prog" > "$prog.run" 2>&1
    result="compiles; the program $(show "$prog.run")"
  else
    result="exit $?, $(show "$prog.mosmlc")"
  fi
  printf '%-12s mosmlc: %s\n' "$prog" "$result"
  "$MOSML" -quietdec "$prog.sml" < /dev/null > "$prog.mosml" 2>&1
  printf '%-12s mosml:  %s\n' "$prog" "$(show "$prog.mosml")"
done
