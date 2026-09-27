#!/bin/sh
# Build and run every program twice: as MLKit builds it by default (with
# garbage collection, so with tagged values) and with -no_gc (untagged
# values). Each is a standalone program built from an .mlb file that lists
# MLKit's Basis Library and the program, with nothing of Rune involved.
# MLKIT names the compiler (default: mlkit on the PATH); SML_LIB must name
# MLKit's library directory (lib/mlkit of the installation).
MLKIT=${MLKIT:-mlkit}
here=$(cd "$(dirname "$0")" && pwd)
out=${TMPDIR:-/tmp}/mlkit-push-immediate
"$MLKIT" --version 2>&1 | head -1
for prog in bug bug-lowest bug-highest ok-below ok-above ok-int ok-registers; do
  for mode in default no_gc; do
    dir=$out/$prog-$mode
    rm -rf "$dir"; mkdir -p "$dir"
    cp "$here/$prog.sml" "$dir/prog.sml"
    printf '$(SML_LIB)/basis/basis.mlb\nprog.sml\n' > "$dir/prog.mlb"
    case $mode in default) flags="" ;; no_gc) flags="-no_gc" ;; esac
    # shellcheck disable=SC2086
    msg=$(cd "$dir" && "$MLKIT" --no_messages $flags -o prog prog.mlb 2>&1 | grep -m1 'Error')
    if [ -x "$dir/prog" ]; then result=$("$dir/prog" 2>&1 | head -1)
    else result="compile error: ${msg##*: }"; fi
    printf '%-13s %-8s %s\n' "$prog" "$mode" "$result"
  done
done
