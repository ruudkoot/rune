#!/bin/sh
# The files of a plan (docs/build.md, The plan), in the order a compile takes
# them: each library's, the program's, then the libraries' final files, which
# is what `rune --build-list` prints of the build the plan was made from.
# The other SML systems build the compiler before there is a rune to read a
# build file with, so they read the committed plans of the programs they build
# (rune.plan, runedoc.plan, ...) with this: sh and awk, no Rune
# (docs/building.md, How a host gets its list). A plan's words it does not
# know, or a path that is not plain, it refuses rather than guess.
# Usage: scripts/plan-files.sh PLAN
set -eu
awk '
function fail(message) { print "plan-files: " FILENAME ":" FNR ": " message > "/dev/stderr"; failed = 1; exit 2 }
FNR == 1 { if ($1 != "rune-plan" || $2 != "1" || NF != 2) fail("not a plan of version 1"); next }
NF == 0 { next }
$1 !~ /^(basis|inline|library|form|requires|export|view|friend|end|program|unit|use|replay|boundary|implements|provenance|input)$/ {
  fail("a plan of version 1 has no " $1)
}
$1 == "library" { inlibrary = 1 }
$1 == "program" { inlibrary = 0 }
$1 == "unit" {
  if (NF < 4 || $3 ~ /%/) fail("a path a host cannot read: " $3)
  final = 0
  for (i = 5; i <= NF; i++) if ($i == "final") final = 1
  if (inlibrary && final) last = last $3 "\n"; else first = first $3 "\n"
}
END {
  if (NR == 0) { print "plan-files: " ARGV[1] ": empty, not a plan" > "/dev/stderr"; exit 2 }
  if (!failed) printf "%s%s", first, last
}
' "$1"
