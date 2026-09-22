#!/bin/sh
# What the suite knows about other implementations of the Basis Library, as
# annotations for the documentation (docs/plans/docgen.md, D5):
#   tests/basis/gen-annotations.sh           write tests/basis/annotations.txt
#   tests/basis/gen-annotations.sh --check   fail if it is not what would be written
# The documentation generator reads annotations.txt (`runedoc --annotations`)
# and never deviations.txt: that file is the business of the suite, and this
# script is the one place that knows its format. annotations.txt is committed,
# and `make check-docs` runs the check, so the copy does not go stale.
#
# A line of deviations.txt, `config-glob | label-glob | CATEGORY | reason`,
# becomes `label-glob | implementation | text`. Left out are
#   * the lines about Rune: they are notes of the doc comments; and those
#     about Rune on the VMs of Windows (rune:windows...), which say what
#     Windows does otherwise (docs/building.md);
#   * WIDTH, XC1-NA and HOST-FLAKY, which describe the suite and not a host;
#   * the lines for xc1 configurations only: Rune's library on a host;
#   * the labels @section/..., @load/... and @absent/..., which name no member.
set -eu
cd "$(dirname "$0")"
check=0
case "${1:-}" in
  --check) check=1 ;;
  "") ;;
  *) echo "usage: tests/basis/gen-annotations.sh [--check]" >&2; exit 2 ;;
esac

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

awk '
function trim(x) { sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x); return x }
# the implementation that a configuration glob names, "" for none of interest
function host(config,   kind, rest, name, version, at, h, bits) {
  if (config == "rune") return ""
  kind = config; sub(/:.*/, "", kind)
  if (kind == "xc1" || kind == "rune") return ""
  rest = config; sub(/^[^:]*:/, "", rest)
  at = index(rest, "@")
  if (at > 0) { name = substr(rest, 1, at - 1); version = substr(rest, at + 1) } else { name = rest; version = "*" }
  bits = ""
  if (name == "mlton") h = "MLton"
  else if (name == "polyml") h = "Poly/ML"
  else if (name == "smlnj*") h = "SML/NJ"
  else if (name == "smlnj") { h = "SML/NJ"; bits = " (64-bit)" }
  else if (name == "smlnj32") { h = "SML/NJ"; bits = " (32-bit)" }
  else if (name == "*") h = "MLton, SML/NJ, Poly/ML"
  else return "?"
  if (version != "*") h = h " " version
  return h bits
}
BEGIN {
  print "# What other implementations of the Basis Library do differently, by the label"
  print "# of the check that shows it. Made by tests/basis/gen-annotations.sh from"
  print "# tests/basis/deviations.txt; do not edit. The format is that of"
  print "# `runedoc --annotations` (docs/doc-comments.md):"
  print "#   label-glob | whom it is about | text"
  print "@title Other implementations"
  print "@intro what the test suite of the library finds MLton, SML/NJ and Poly/ML to do differently, under the members whose checks show it. A remark that names a version is known of that version only; docs/basis-compat.md has the versions that were compared and the comparison as a whole."
}
/^[ \t]*#/ || /^[ \t]*$/ { next }
{
  n = split($0, f, "|")
  if (n < 4) { print "gen-annotations.sh: deviations.txt:" NR ": not four fields" > "/dev/stderr"; bad = 1; next }
  config = trim(f[1]); label = trim(f[2]); category = trim(f[3])
  # the reason is the rest of the line: it may hold a bar itself
  reason = f[4]; for (i = 5; i <= n; i++) reason = reason "|" f[i]
  reason = trim(reason)
  if (category == "WIDTH" || category == "XC1-NA" || category == "HOST-FLAKY") next
  if (label ~ /^@/) next
  h = host(config)
  if (h == "") next
  if (h == "?") { print "gen-annotations.sh: deviations.txt:" NR ": unknown configuration " config > "/dev/stderr"; bad = 1; next }
  if (category == "HOST-BUG") text = reason
  else if (category == "HOST-ABSENT") text = "not there: " reason
  else if (category == "SPEC-AMBIGUOUS") text = "another reading of the specification: " reason
  else { print "gen-annotations.sh: deviations.txt:" NR ": unknown category " category > "/dev/stderr"; bad = 1; next }
  line = label " | " h " | " text
  if (!(line in seen)) { seen[line] = 1; print line }
}
END { exit bad }
' deviations.txt > "$tmp"

if [ $check = 1 ]; then
  if cmp -s "$tmp" annotations.txt; then
    echo "gen-annotations: annotations.txt is up to date ($(grep -c -v '^[#@]' annotations.txt) annotations)"
  else
    echo "gen-annotations: tests/basis/annotations.txt is not what deviations.txt gives (run tests/basis/gen-annotations.sh, then make docs)" >&2
    exit 1
  fi
else
  cp "$tmp" annotations.txt
  echo "gen-annotations: wrote annotations.txt ($(grep -c -v '^[#@]' annotations.txt) annotations)"
fi
