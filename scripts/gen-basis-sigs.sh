#!/bin/sh
# The signatures of the specification in the basis library, and the
# transcriptions of tests/basis/spec-sigs that they are checked against.
#   scripts/gen-basis-sigs.sh [--check] [LIBDIR]
# LIBDIR defaults to lib.
#
# A signature of lib/basis is written by hand and carries the documentation of
# the library (docs/plans/docgen.md). The transcription SPEC_<SIG> stays what
# it was: the signature as the page of the specification has it, written
# independently of lib/basis, which the suite matches Rune's structures
# against. The two must say the same: after the renaming SPEC_<SIG> -> <SIG>
# they have the same tokens (comments and layout are free). That holds for the
# files sig_<sig>.sml and for the signatures lib/basis declares elsewhere
# because its structures are sealed with them (INTEGER, WORD, PRIM_IO,
# STREAM_IO, the MONO_* ones). The partial transcriptions (*_IMP) have no
# signature in the library.
#
# Without --check: a transcription that has no signature in lib/basis yet gets
# a file sig_<sig>.sml, a renamed copy to start from, and the block of
# lib/basis/MANIFEST that lists the sig_ files is rewritten. An existing
# signature file is never written or removed.
# With --check (make check-docs): nothing changes; fails when the block is out
# of date, a signature is missing, its tokens differ from its transcription,
# or a sig_ file has no transcription. The tokens come from
# `$RUNE --dump-tokens` (default bin/rune).
set -u
check=0
[ "${1:-}" = --check ] && { check=1; shift; }
cd "$(dirname "$0")/.."
lib=${1:-lib}
rune=${RUNE:-bin/rune}
basis=$lib/basis
manifest=$basis/MANIFEST
begin='# ---- the signatures of the specification (scripts/gen-basis-sigs.sh)'
end='# ---- end of the signatures'
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
status=0

# The MANIFEST without the generated block, a line @BLOCK@ where it was, and
# the names its files provide.
awk -v b="$begin" -v e="$end" '$0 == b { skip = 1; print "@BLOCK@"; next } $0 == e { skip = 0; next } !skip' "$manifest" > "$tmp/manifest.base"
awk -F '|' '!/^[[:space:]]*(#|$|@BLOCK@)/ { n = split($4, p, " "); for (i = 1; i <= n; i++) print p[i] }' "$tmp/manifest.base" | sort -u > "$tmp/provided"
# The signatures lib/basis declares itself (a structure and a signature can
# have the same name, IO and OS: only these count).
# A sig_ file that the MANIFEST lists outside the block is the library's own
# too: its structure is sealed with it where it is declared, so it comes
# before the structure and not with the others (sig_time.sml).
for f in $(awk -F '|' '!/^[[:space:]]*(#|$|@BLOCK@)/ { gsub(/ /, "", $1); print $1 }' "$tmp/manifest.base"); do
  sed -n 's/^signature \([A-Z0-9_]*\).*/\1/p' "$basis/$f"
done | sort -u > "$tmp/own"

# The files to generate: SIG and the transcription it comes from.
: > "$tmp/sigs"
for f in tests/basis/spec-sigs/*.sml; do
  case "$f" in *_IMP.sml) continue ;; esac
  for s in $(sed -n 's/^signature SPEC_\([A-Z0-9_]*\).*/\1/p' "$f"); do
    grep -q -x "$s" "$tmp/own" && continue
    printf '%s %s\n' "$s" "$f" >> "$tmp/sigs"
  done
done
cut -d ' ' -f 1 "$tmp/sigs" | sort -u > "$tmp/generated"
cat "$tmp/provided" "$tmp/generated" | sort -u > "$tmp/all"

# Write each file, and find what it requires: the names in it that another
# file provides, heads of long identifiers only, as the loader counts them (a
# signature's own name excepted).
mkdir -p "$tmp/out"
: > "$tmp/edges"
: > "$tmp/lines"
while read -r sig src; do
  name=sig_$(echo "$sig" | tr 'A-Z' 'a-z').sml
  sed 's/SPEC_\([A-Z0-9_]*\)/\1/g' "$src" > "$tmp/out/$name"
  # identifiers, and the heads of long identifiers, outside comments
  requires=$(sed 's/SPEC_\([A-Z0-9_]*\)/\1/g' "$src" |
    awk '{ line = $0; out = "";
           while (length(line) > 0) {
             if (depth == 0 && substr(line, 1, 2) == "(*") { depth = 1; line = substr(line, 3); continue }
             if (depth > 0) {
               if (substr(line, 1, 2) == "(*") { depth++; line = substr(line, 3); continue }
               if (substr(line, 1, 2) == "*)") { depth--; line = substr(line, 3); continue }
               line = substr(line, 2); continue
             }
             out = out substr(line, 1, 1); line = substr(line, 2)
           }
           print out }' |
    grep -o "[A-Za-z][A-Za-z0-9_']*\(\.[A-Za-z][A-Za-z0-9_']*\)*" | sed 's/\..*//' |
    sort -u | grep -x -F -f "$tmp/all" | grep -v -x "$sig" | tr '\n' ' ')
  printf '%s | demand | yes  | %s | %s\n' "$name" "$sig" "$requires" | sed 's/ *$//' >> "$tmp/lines"
  echo "$sig $sig" >> "$tmp/edges"
  for r in $requires; do
    grep -q -x "$r" "$tmp/generated" && echo "$r $sig" >> "$tmp/edges"
  done
done < "$tmp/sigs"

# The block, in an order where a signature comes after those it names.
{
  echo "$begin"
  for sig in $(tsort "$tmp/edges"); do
    grep "| $sig |" "$tmp/lines"
  done
  echo "$end"
} > "$tmp/block"
# The block goes where it was, so that the files after it can use the
# signatures; the first time, before the files compiled after the program.
awk -v blockfile="$tmp/block" -v had="$(grep -c -x '@BLOCK@' "$tmp/manifest.base")" '
  $0 == "@BLOCK@" { while ((getline l < blockfile) > 0) print l; done = 1; next }
  !done && !had && /^[^#]*\| *final *\|/ { while ((getline l < blockfile) > 0) print l; done = 1 }
  { print }
  END { if (!done) while ((getline l < blockfile) > 0) print l }
' "$tmp/manifest.base" > "$tmp/manifest.new"

# tokens FILE...: "SIG<TAB>token" for every token of every signature
# declaration of the files, in order. A declaration ends where the next
# top-level declaration begins.
tokens() {
  "$rune" --dump-tokens "$@" | sed 's/^[^ ]* //' | awk '
    depth == 0 && ($0 == "signature" || $0 == "structure" || $0 == "functor") {
      sig = ""; if ($0 == "signature") want = 1; next }
    $0 == "<eof>" { sig = ""; next }
    want { sig = $0; want = 0; next }
    $0 == "sig" || $0 == "struct" || $0 == "let" || $0 == "local" { depth++ }
    $0 == "end" { depth-- }
    sig != "" { print sig "\t" $0 }'
}

# The signatures of the transcriptions, renamed, and those of lib/basis.
: > "$tmp/specfiles"
for f in tests/basis/spec-sigs/*.sml; do
  case "$f" in *_IMP.sml) continue ;; esac
  sed 's/SPEC_\([A-Z0-9_]*\)/\1/g' "$f" > "$tmp/spec_$(basename "$f")"
  echo "$tmp/spec_$(basename "$f")" >> "$tmp/specfiles"
done
compare() {
  # shellcheck disable=SC2046
  tokens $(cat "$tmp/specfiles") > "$tmp/spec.tok" || { echo "gen-basis-sigs: cannot read the tokens of the transcriptions"; return 1; }
  # shellcheck disable=SC2046
  tokens $(grep -l '^signature ' "$basis"/*.sml) |
    # PRIM_IO is declared before OS.IO can be named: RuneIODesc.iodesc is that type.
    awk -F '\t' '$1 == "PRIM_IO" && $2 == "RuneIODesc.iodesc" { print $1 "\tOS.IO.iodesc"; next } { print }' > "$tmp/lib.tok" ||
    { echo "gen-basis-sigs: cannot read the tokens of $basis"; return 1; }
  bad=0
  for sig in $(cut -f 1 "$tmp/spec.tok" | sort -u); do
    grep "^$sig	" "$tmp/spec.tok" > "$tmp/a.tok"
    grep "^$sig	" "$tmp/lib.tok" > "$tmp/b.tok"
    if [ ! -s "$tmp/b.tok" ]; then
      echo "gen-basis-sigs: signature $sig is transcribed in tests/basis/spec-sigs and missing from $basis (run scripts/gen-basis-sigs.sh for a copy to start from)"; bad=1
    elif ! cmp -s "$tmp/a.tok" "$tmp/b.tok"; then
      echo "gen-basis-sigs: signature $sig of $basis differs from its transcription; the first difference (transcription, library):"
      diff "$tmp/a.tok" "$tmp/b.tok" | grep '^[<>]' | head -2 | sed 's/^/  /'
      bad=1
    fi
  done
  return $bad
}

if [ $check = 1 ]; then
  cmp -s "$tmp/manifest.new" "$manifest" || { echo "gen-basis-sigs: the block of $manifest is not up to date (run scripts/gen-basis-sigs.sh)"; status=1; }
  compare || status=1
  for f in "$basis"/sig_*.sml; do
    [ -f "$f" ] || continue
    # one that the MANIFEST lists outside the block is compared by its tokens, as the library's own are
    sig=$(sed -n 's/^signature \([A-Z0-9_]*\).*/\1/p' "$f" | head -1)
    [ -f "$tmp/out/$(basename "$f")" ] || grep -q "^signature SPEC_$sig\b" tests/basis/spec-sigs/*.sml ||
      { echo "gen-basis-sigs: $f has no transcription any more (remove it, and rerun scripts/gen-basis-sigs.sh)"; status=1; }
  done
  [ $status = 0 ] && echo "gen-basis-sigs: OK ($(cut -f 1 "$tmp/spec.tok" | sort -u | wc -l | tr -d ' ') signatures have the tokens of their transcriptions)"
  exit $status
fi
new=0
for f in "$tmp"/out/*.sml; do
  [ -f "$f" ] || continue
  [ -f "$basis/$(basename "$f")" ] && continue
  cp "$f" "$basis/"
  echo "gen-basis-sigs: wrote $basis/$(basename "$f"), a copy of its transcription"
  new=$((new + 1))
done
cp "$tmp/manifest.new" "$manifest"
echo "gen-basis-sigs: $new new signature files in $basis; the block of $manifest is written"
