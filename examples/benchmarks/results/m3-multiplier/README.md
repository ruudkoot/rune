# Stream multiplier validation

All four trace/count variants pass all 112 primary smoke/normal cases across Rune
O0/O2 engines and six managed native SML hosts. Twenty semantic invocations pass
all 56 assertions: 1120 passing assertions, none failed or unreached. Sixteen full
normal count samples agree. Twelve serial single fresh-process native smoke
adapter samples pass, separately from instrumentation and performance claims.

Unmodified GHC matches every FAST/NORM/SLOW fixture at 32, 256 and 512 input bits
and 2000 clocks. Eight export-only trace/count observations agree with an
independent masked shift/add clock model. Small-width truncation, clock ordering,
truth tables, signed-64 conversion and strictness checks pass. Lazy binary heads
preserve the active source lift21; strict heads correspond to its commented
alternative. Both retain unary headstrict, latches, recursive wire sharing,
delayed word arguments/tails, adder pairing and spine-only wide-gate length.

The inactive runMult consumer is a separate pair of programs. It sums ready bits
and leaves the product stream pending, as the demand control demonstrates; it is
not described as forcing the whole product calculation. Normal/large sums are
222, smoke is three. Trace variants check all original characters. Normal and
large keep source widths/cycles; smoke reduces FAST to sixteen clocks. Full final
SML large runs remain unrecorded. Earlier complete normal pilots and recursive-
forcing failures are labelled development evidence, separate from final source
identities and canonical results. No compiler/runtime feature is added.

Source authorship/copyright and the count-consumer supplementary inventory entry
are recorded. All 102 inventory regressions and five-pin replay pass. The shared
full make JOBS=4 check transcript exits zero with 1159 profiles and all compiler,
runedoc and runeopt cross-build comparisons. Outstanding source imports remain
scheduled; M3/M4/M5 are in progress and M8 remains planned.
