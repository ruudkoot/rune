#!/bin/sh
# The files of a program's build file's `files ... end` blocks, one per line,
# in order: the sources of the compiler, runedoc, runeopt, runeisa and runeffi, which
# the hosts' build files are made from (scripts/gen-build-files.sh) and the
# Makefile compiles, both before there is a rune to read a build file with
# (docs/build.md). Comments are SML's.
#   scripts/build-files.sh FILE.build
set -eu
awk '
  { text = text $0 "\n" }
  END {
    # comments out, nested ones too
    out = ""; depth = 0; n = length(text)
    for (i = 1; i <= n; i++) {
      c = substr(text, i, 2)
      if (c == "(*") { depth++; i++; continue }
      if (depth > 0 && c == "*)") { depth--; i++; continue }
      if (depth == 0) out = out substr(text, i, 1)
    }
    m = split(out, w, /[ \t\n]+/); inside = 0
    for (j = 1; j <= m; j++) {
      if (w[j] == "") continue
      if (w[j] == "files") { inside = 1; continue }
      if (w[j] == "end") { inside = 0; continue }
      if (inside) print w[j]
    }
  }' "$1"
