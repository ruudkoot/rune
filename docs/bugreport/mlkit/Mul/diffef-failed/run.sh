#!/bin/sh
# Build and run every program three ways: as MLKit builds it by default,
# without its optimiser (-no_opt), and without the contraction of its
# lambda optimiser (--no_contract). Each program uses MLKit's own Basis
# Library only, through an .mlb file; the two files ok-other-unit-a.sml and
# ok-other-unit-b.sml are one program of two compilation units.
# MLKIT names the compiler (default: mlkit on the PATH) and SML_LIB its
# library (default: lib/mlkit next to its bin/). MLKit writes what it
# compiles next to the sources, so every build copies them into a
# directory of its own under $TMPDIR.
MLKIT=${MLKIT:-mlkit}
MLKIT=$(command -v "$MLKIT")
SML_LIB=${SML_LIB:-$(dirname "$(dirname "$MLKIT")")/lib/mlkit}
export SML_LIB
cd "$(dirname "$0")"
out=${TMPDIR:-/tmp}/mlkit-diffef
rm -rf "$out"
"$MLKIT" --version 2>&1 | head -1
for prog in bug bug-tree bug-own-app bug-helper ok-no-argument ok-built-once ok-mutual ok-other-unit; do
  case $prog in
    ok-other-unit) files="ok-other-unit-a.sml ok-other-unit-b.sml" ;;
    *) files="$prog.sml" ;;
  esac
  for mode in default no-opt no-contract; do
    case $mode in
      default) flags="" ;;
      no-opt) flags="-no_opt" ;;
      no-contract) flags="--no_contract" ;;
    esac
    dir=$out/$prog-$mode
    mkdir -p "$dir"
    # shellcheck disable=SC2086
    cp $files "$dir"
    { echo '$(SML_LIB)/basis/basis.mlb'; for f in $files; do echo "$f"; done; } > "$dir/prog.mlb"
    # shellcheck disable=SC2086
    if (cd "$dir" && "$MLKIT" --no_messages $flags -o prog prog.mlb > log 2>&1); then
      result=$("$dir/prog" 2>&1 | head -1)
    else
      result="compiler: $(grep -m 1 '^Impossible' "$dir/log")"
    fi
    printf '%-15s %-12s %s\n' "$prog" "$mode" "$result"
  done
done
