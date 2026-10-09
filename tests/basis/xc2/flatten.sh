#!/bin/sh
# The sources of a flattened ML Basis file as one sequence of SML files.
#   tests/basis/xc2/flatten.sh FLAT OUTDIR BASIS CMD...
# FLAT is the output of mlb-flatten.awk; each source is written by
# `CMD... FILE` (the host's rewriting of its extensions) to
# OUTDIR/src/NNNN-NAME.sml, after a comment with its path under BASIS, on the
# same line so that the line numbers are the source's. OUTDIR/files lists
# them in order.
#
# The scoping of `local A in B end`: A's bindings are seen by B and not after.
# The sources are one sequence, so what A rebinds is saved before A
# (structure XC2SaveL_S = S) and restored after B, unless B rebinds it too.
# Only structures are saved: the signatures, functors, types and values that
# a local part binds are the same whenever the library binds them again. The
# names are those toplevel.awk finds.
set -eu
flat=$1; out=$2; basis=$3; shift 3
here=$(cd "$(dirname "$0")" && pwd)

awk '
function structures(file,   cmd, n) {
  delete S
  cmd = "awk -f \"" here "/toplevel.awk\" \"" file "\""
  while ((cmd | getline n) > 0) S[n] = 1
  close(cmd)
}
$1 == "local" { d++; phase[d] = "A"; id[d] = ++L; start[L] = clock; next }
$1 == "file" {
  clock++; structures($2)
  for (n in S) { if (!(n in BOUNDAT)) BOUNDAT[n] = clock; if (d > 0) NAMES[d, phase[d], n] = 1 }
  next
}
$1 == "in" { phase[d] = "B"; next }
$1 == "end" {
  for (key in NAMES) {
    split(key, p, SUBSEP)
    if (p[1] != d) continue
    if (p[2] == "A" && BOUNDAT[p[3]] <= start[id[d]]) {
      print "save", id[d], p[3]
      if (!((d, "B", p[3]) in NAMES)) print "restore", id[d], p[3]
    }
    if (p[2] == "B" && d > 1) NAMES[d - 1, phase[d - 1], p[3]] = 1
    delete NAMES[key]
  }
  d--; next
}
' here="$here" "$flat" | sort > "$out/scopes"

rm -rf "$out/src"; mkdir "$out/src"
: > "$out/files"
n=0; L=0; stack=
next_src() { # next_src NAME: set f to the path of the next source, NAME
  n=$((n + 1)); f=$(printf '%s/src/%04d-%s.sml' "$out" "$n" "$1")
  echo "$f" >> "$out/files"
}
while read -r kind arg; do
  case $kind in
    local)
      L=$((L + 1)); stack="$L $stack"
      if grep -q "^save $L " "$out/scopes"; then
        next_src "xc2-save-$L"
        awk -v L="$L" '$1 == "save" && $2 == L { print "structure XC2Save" L "_" $3 " = " $3 }' "$out/scopes" > "$f"
      fi ;;
    in) ;;
    end)
      k=${stack%% *}; stack=${stack#* }
      if grep -q "^restore $k " "$out/scopes"; then
        next_src "xc2-restore-$k"
        awk -v L="$k" '$1 == "restore" && $2 == L { print "structure " $3 " = XC2Save" L "_" $3 }' "$out/scopes" > "$f"
      fi ;;
    file)
      name=${arg##*/}; name=${name%.*}; next_src "$name"
      { printf "(* %s *) " "${arg#"$basis"/}"; "$@" "$arg"; } > "$f" ;;
  esac
done < "$flat"
