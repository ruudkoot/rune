#!/bin/sh
# How far Rune gets on another system's Basis Library sources -- the fourth
# quadrant of the test matrix (Rune as the compiler, a host's library):
#   tests/external/probe-host-basis.sh [--rune BIN] DIR...
# Every *.sml under DIR is given to `rune --no-prelude --typecheck-only
# --allow-prim`, which needs none of the library, and the first message is
# put in one of five classes:
#
#   ok       Rune took the file whole
#   unbound  it parses and elaborates as far as a name the file expects from
#            the rest of that library (its primitive layer, or a file that
#            would have been loaded before it)
#   fixity   it parses only where the ambient fixity is the one the library's
#            build sets, not the default of the top level: MLton's .mlb files
#            compile parts of the basis with `<` and `>` not infix, so
#            `fun > (a, b) = < (b, a)` is prefix application there
#   syntax   Rune's parser will not take it: an extension of that compiler
#   other    anything else
#
# The point of the count is the size of the work: `ok` and `unbound` are the
# files a shim for the library's primitive layer would reach, and `syntax`
# are the ones the shim would have to replace. Prints a line per class and,
# with --list, a line per file.
set -u
rune=bin/rune
list=0
dirs=""
while [ $# -gt 0 ]; do
  case $1 in
    --rune) rune=$2; shift 2 ;;
    --list) list=1; shift ;;
    -*) echo "usage: $0 [--rune BIN] [--list] DIR..." >&2; exit 2 ;;
    *) dirs="$dirs $1"; shift ;;
  esac
done
[ -n "$dirs" ] || { echo "usage: $0 [--rune BIN] [--list] DIR..." >&2; exit 2; }
[ -x "$rune" ] || { echo "probe-host-basis: $rune is missing (run make)" >&2; exit 2; }

out=tests/out/external
mkdir -p "$out"
tmp=$out/host-basis.tsv
: > "$tmp"
# `nonfix` for what a library's own build may have made prefix
nf=$out/host-basis-nonfix.sml
printf 'nonfix < > <= >= + - * div mod ^ @ :: o before = <> ;\n' > "$nf"

for d in $dirs; do
  [ -d "$d" ] || { echo "probe-host-basis: no directory $d" >&2; exit 2; }
  for f in $(find "$d" -name '*.sml' | sort); do
    err=$("$rune" --no-prelude --typecheck-only --allow-prim "$f" 2>&1 | head -1)
    if [ -z "$err" ]; then kind=ok
    else
      case "$err" in
        *"unbound"*) kind=unbound ;;
        *"infix"*)
          cat "$nf" "$f" > "$out/host-basis-try.sml"
          if [ -z "$("$rune" --no-prelude --typecheck-only --allow-prim "$out/host-basis-try.sml" 2>&1 | head -1)" ]
          then kind=fixity
          else kind=fixity
          fi ;;
        *"expected"*|*"unexpected"*|*"illegal"*|*"unterminated"*) kind=syntax ;;
        *) kind=other ;;
      esac
    fi
    printf '%s\t%s\t%s\n' "$kind" "$f" "$err" >> "$tmp"
  done
done
rm -f "$out/host-basis-try.sml" "$nf"

[ "$list" = 1 ] && cut -f 1,2 "$tmp"
total=$(wc -l < "$tmp")
echo "probe-host-basis: $total files"
for k in ok unbound fixity syntax other; do
  n=$(cut -f 1 "$tmp" | grep -c -x "$k" || true)
  [ "$n" = 0 ] || printf '  %-8s %4d\n' "$k" "$n"
done
echo "  (the classes are described in the header; $tmp has a line per file)"
