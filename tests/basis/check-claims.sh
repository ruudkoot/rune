#!/bin/sh
# The structures that the library's documentation says implement a signature
# (docs/generated/basis/claims.tsv, written by runedoc from the `Implements:`
# paragraphs and the ascriptions of lib/basis) against the structures that
# this suite matches against the specification's signatures
# (`structure C : SPEC_SIG ... = Structure` in tests/basis/*_sig.sml):
#   - what the suite matches, the library claims;
#   - a signature of the library's own says `Status: extension`, and one the
#     specification has does not;
#   - what the library claims in a comment, the suite matches, unless the
#     signature is the library's own and spec-sigs does not transcribe it
#     (an ascription
#     in the source is checked by the compiler, and a substructure inherited
#     through `structure A = B` is B's).
# So a claim cannot be wrong without a test failing, and a structure that is
# tested cannot go unlisted. make check-docs runs this.
#   tests/basis/check-claims.sh [CLAIMS.tsv]
set -u
cd "$(dirname "$0")/../.."
claims=${1:-docs/generated/basis/claims.tsv}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
status=0

[ -f "$claims" ] || { echo "check-claims: no $claims (run make docs)"; exit 1; }

# "Structure SIG" for every line of the suite, the partial transcriptions
# (SPEC_*_IMP) left out. An ascription that goes on over several lines, each
# of which begins with `where`, is read as one.
cat tests/basis/*_sig.sml |
  awk 'held != "" { t = $0; sub(/^[ \t]+/, "", t)
                    if (t ~ /^where /) { held = held " " t; next }
                    print held; held = "" }
       /^[ \t]*structure [A-Za-z0-9_]* :>* *SPEC_/ { held = $0; next }
       { print }
       END { if (held != "") print held }' |
  sed -n 's/^[[:space:]]*structure [A-Za-z0-9_]* :>* *SPEC_\([A-Z0-9_]*\)\( .*\)* = \([A-Za-z0-9_.'"'"']*\)[[:space:]]*$/\3 \1/p' |
  grep -v '_IMP$' | sort -u > "$tmp/suite"

awk -F '\t' 'NR > 1 && $2 == "structure" { print $1 " " $3 }' "$claims" | sort -u > "$tmp/all"
awk -F '\t' 'NR > 1 && $2 == "structure" && $6 == "claimed" { print $1 " " $3 }' "$claims" | sort -u > "$tmp/claimed"

# A signature the specification has, tests/basis/spec-sigs transcribes; one it
# does not have, it does not. So the transcriptions say which of the library's
# signatures may call themselves `required` or `optional` -- those words are
# about the specification -- and which must say `extension`. Without this a
# signature of the library's own reads on its page exactly like one of the
# specification's, which is what it is not.
awk -F '\t' 'NR > 1 && $2 == "signature" { print $1 "\t" $5 "\t" $7 }' "$claims" |
while IFS="$(printf '\t')" read -r sig st src; do
  if [ -f "tests/basis/spec-sigs/$sig.sml" ]; then
    [ "$st" = extension ] &&
      { echo "check-claims: $sig says \`Status: extension\` ($src), and tests/basis/spec-sigs/$sig.sml transcribes it from the specification"
        echo x >> "$tmp/status-bad"; }
  else
    [ "$st" = extension ] ||
      { echo "check-claims: $sig says \`Status: $st\` ($src), which is a word about the specification, and tests/basis/spec-sigs has no transcription of it: say \`Status: extension\`"
        echo x >> "$tmp/status-bad"; }
  fi
done
# A signature that nothing implements is the library's own plumbing and
# should be named for the library, so that it stays out of the documentation:
# the two that held the byte vector's representation were documented as
# signatures of the specification until they were renamed.
awk -F '\t' 'NR > 1 && $2 == "signature" { sig[$1] = $7 }
              NR > 1 && $2 != "signature" && $3 != "" { impl[$3] = 1 }
              END { for (s in sig) if (!(s in impl)) print s "\t" sig[s] }' "$claims" |
while IFS="$(printf '\t')" read -r sig src; do
  echo "check-claims: nothing implements $sig ($src): a signature the library needs for itself is named RUNE_... and stays out of the documentation"
  echo x >> "$tmp/status-bad"
done

[ -f "$tmp/status-bad" ] && status=1

# every transcribed signature is matched by some structure
for f in tests/basis/spec-sigs/*.sml; do
  case "$f" in *_IMP.sml) continue ;; esac
  for sig in $(sed -n 's/^signature SPEC_\([A-Z0-9_]*\).*/\1/p' "$f"); do
    grep -q " $sig\$" "$tmp/suite" ||
      { echo "check-claims: no tests/basis/*_sig.sml matches a structure against SPEC_$sig ($f)"; status=1; }
  done
done

comm -23 "$tmp/suite" "$tmp/all" > "$tmp/unclaimed"
comm -13 "$tmp/suite" "$tmp/claimed" > "$tmp/untested"
if [ -s "$tmp/unclaimed" ]; then
  status=1
  sed 's/^\(.*\) \(.*\)$/check-claims: the suite matches \1 against \2, and no comment of lib\/basis says `Implements: \2` for it/' "$tmp/unclaimed"
fi
# A signature of the library's own, which the specification does not have and
# spec-sigs therefore does not transcribe, is matched by the ascription in its
# seal file and by nothing here: there is no SPEC_ to match it against.
: > "$tmp/untested.spec"
while read -r line; do
  sig=${line##* }
  [ -f "tests/basis/spec-sigs/$sig.sml" ] && printf '%s\n' "$line" >> "$tmp/untested.spec"
done < "$tmp/untested"
if [ -s "$tmp/untested.spec" ]; then
  status=1
  sed 's/^\(.*\) \(.*\)$/check-claims: \1 says `Implements: \2`, and no tests\/basis\/*_sig.sml matches it against SPEC_\2/' "$tmp/untested.spec"
fi
[ $status = 0 ] && echo "check-claims: OK ($(wc -l < "$tmp/suite" | tr -d ' ') pairs of a structure and a signature, claimed and tested)"
exit $status
