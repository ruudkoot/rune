#!/bin/sh
# Generate what Rune compiles a program of the xc2:smlnj-dev configuration of
# tests/basis/run-matrix.sh with: the library of SML/NJ 2026.2, as
# tests/basis/xc2/smlnj-legacy/gen.sh makes that of 110.99.9, with the
# basis.patch here and more-inline.sml, which extends the InlineT there
# with what 2026.2's adds.
#   tests/basis/xc2/smlnj-dev/gen.sh OUTDIR SMLNJ      (RUNE: bin/rune)
# SMLNJ is the installation of 2026.2, whose system directory holds the
# sources of its library (scripts/fetch-hosts.sh keeps them there).
XC2_SMLNJ_PORT=smlnj-dev exec sh "$(dirname "$0")/../smlnj-legacy/gen.sh" "$@"
