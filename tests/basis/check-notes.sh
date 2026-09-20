#!/bin/sh
# The readings and deviations that the library's documentation records
# (docs/generated/basis/notes.tsv, written by runedoc from the notes of the
# doc comments) against what this suite records in deviations.txt. The
# documentation is where a reading is written down; this file only explains
# failures. So the suite reads the documentation's export, and runedoc never
# reads deviations.txt (docs/plans/docgen.md, D5):
#   1. a `rune` line of category RUNE-DEV or SPEC-AMBIGUOUS says that Rune
#      fails a check because it reads the specification differently from the
#      suite, or departs from it: a note says so (`Reading (the suite
#      differs):`, `Deviation:`) and is pinned by that check; and every note
#      that says the suite differs has such a line;
#   2. for a signature that is documented in full (lib/basis/DOCUMENTED), a
#      SPEC-AMBIGUOUS line of a host about a member of it has a `Reading:` of
#      that member: what the hosts read differently is a reading we took.
# make check-docs runs this.
#   tests/basis/check-notes.sh [NOTES.tsv [CLAIMS.tsv]]
set -u
cd "$(dirname "$0")/../.."
notes=${1:-docs/generated/basis/notes.tsv}
claims=${2:-docs/generated/basis/claims.tsv}
deviations=tests/basis/deviations.txt
documented=lib/basis/DOCUMENTED
status=0
[ -f "$notes" ] || { echo "check-notes: no $notes (run make docs)"; exit 1; }

# overlap A B: two globs can name the same label (either matches the other,
# taken as text)
overlap() {
  # shellcheck disable=SC2254
  case "$1" in $2) return 0 ;; esac
  # shellcheck disable=SC2254
  case "$2" in $1) return 0 ;; esac
  return 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# "config|label|category" of the data lines
awk -F '|' '!/^[[:space:]]*(#|$)/ && NF >= 4 { for (i = 1; i <= 3; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i); print $1 "|" $2 "|" $3 }' \
  "$deviations" > "$tmp/lines"

# 1. the lines about Rune, and the notes that say the suite differs or Rune deviates
grep '^rune|' "$tmp/lines" | grep -E '\|(RUNE-DEV|SPEC-AMBIGUOUS)$' | cut -d '|' -f 2 > "$tmp/rune"
awk -F '\t' 'NR > 1 && ($3 == "differs" || $2 == "Deviation") { print $1 "\t" $7 }' "$notes" > "$tmp/differ"
while read -r label; do
  found=0
  while IFS='	' read -r id pins; do
    for p in $pins; do overlap "$label" "$p" && found=1; done
  done < "$tmp/differ"
  [ $found = 1 ] ||
    { echo "check-notes: deviations.txt explains the failure of $label on rune, and no note of the documentation (Reading (the suite differs):, Deviation:) is pinned by it"; status=1; }
done < "$tmp/rune"
awk -F '\t' 'NR > 1 && $3 == "differs" { print $1 "\t" $7 }' "$notes" > "$tmp/suite-differs"
while IFS='	' read -r id pins; do
  found=0
  while read -r label; do
    for p in $pins; do overlap "$label" "$p" && found=1; done
  done < "$tmp/rune"
  [ $found = 1 ] ||
    { echo "check-notes: the note $id says that the suite differs, and deviations.txt has no rune line for a check that pins it"; status=1; }
done < "$tmp/suite-differs"

# 2. the host lines about members of documented signatures
grep -E '\|SPEC-AMBIGUOUS$' "$tmp/lines" | grep -v '^rune|' | cut -d '|' -f 2 | sort -u > "$tmp/host"
count=0
while read -r label; do
  scope=${label%%/*}
  case "$scope" in @*|\**) continue ;; esac           # @load/..., and globs over structures
  structure=${scope%.*}
  member=${scope##*.}
  # a structure may claim several signatures (TextIO: TEXT_IO and
  # IMPERATIVE_IO), and the member belongs to one of them; the note is
  # written once, wherever the member is specified
  sigs=$(awk -F '\t' -v s="$structure" 'NR > 1 && $1 == s { print $3 }' "$claims" |
           while read -r s; do grep -q -x "$s" "$documented" 2> /dev/null && echo "$s"; done)
  [ -n "$sigs" ] || continue
  count=$((count + 1))
  found=0
  for sig in $sigs; do
    awk -F '\t' -v sig="$sig" -v m="$member" 'NR > 1 && $2 == "Reading" && $4 == sig && $5 == m { found = 1 } END { exit !found }' "$notes" &&
      found=1
  done
  [ $found = 1 ] ||
    { echo "check-notes: a host reads $scope differently ($label in deviations.txt), and none of $(echo "$sigs" | tr '\n' ' ')which $structure claims and which are documented in full, has a Reading: for $member"; status=1; }
done < "$tmp/host"

[ $status = 0 ] && echo "check-notes: OK ($(wc -l < "$tmp/rune" | tr -d ' ') rune lines and $(wc -l < "$tmp/suite-differs" | tr -d ' ') notes that differ agree; $count host readings of documented signatures have their note)"
exit $status
