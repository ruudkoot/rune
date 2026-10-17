# GAMTEB application validation

Fifty of 56 primary smoke/normal cases pass. All 32 Rune cases pass at O0/O2.
Native MLton, Poly/ML, ML Kit and development SML/NJ pass all four cases each.
Legacy 64-bit SML/NJ passes smoke and fails both normal cases; legacy 32-bit
SML/NJ fails all four exact decimal-roundtrip checks. No failed correctness
check supplies an accepted measurement.

The raw-stream kernel target records 553 passes and seven failed assertions
across twenty 28-check invocations. Only 64-bit legacy SML/NJ fails: four
assertions in the first invocation and three in the second. The full 409-check
target records 8060 passing assertions, 108 failures and twelve unreached checks.
MLton fails the two negative-zero formatter diagnostics in each invocation.
Development SML/NJ records 396 passes/11 failures/two unreached per invocation;
legacy 64-bit records 395/12/two, and legacy 32-bit records 378/29/two.
The remaining twelve invocations pass all 409 checks.
Combined totals are 8613 passes, 115 failures and twelve unreached.

The host note separates decimal roundtrip failures, generic real tuples inside
references, nursery-sensitive corruption and arithmetic approximation results.
Small standalone controls and all raw transcripts remain. No compiler or
benchmark workaround is included. Auxiliary diagnostic bounds are distinguished
from the primary result bounds. Numeric-zero accumulation checks remain exact.

Eight complete normal count samples agree under Rune's engine rules, including
allocation across all four engines. Six serial single fresh-process native
smoke samples validate adapters separately from instrumentation. Existing budgets
and the default ten-sample policy are unchanged.

Unmodified GHC programs match all three upstream fixtures. Export-only observers
expose ordered results/statistics and accumulation arrays. An independent eager
event queue matches every raw value exactly at seven particle counts; separate
ordered sums match all twelve statistics and 105 result cells. Full final-source
Rune O2 calibration passes all original 200-iteration normal and large profiles
under both numeric policies within one recorded 600-second/RSS guard.

The port preserves source generation, branching, random arithmetic, concatenation
and accumulation order, shared result/statistic streams and historical numerical
quirks. The source output order and lazily cached table prefix remain. GEN17,
buffered text, explicit Word64 hash checking and stable reports are documented
consumer adaptations. Complete Regents 1990 notices remain on derived physics
modules, driver and independent model.

The supplementary inventory records each historical LML/Id/Fortran reference,
its identity, notice and disposition. Foreign-language reference implementations
remain future candidates outside the initial runnable language-family set.
Missing legacy numeric/dataflow facilities have explicit reconsideration
conditions. No materially different historical program is called a duplicate.

All 78 inventory regression tests pass, and five clean pins reproduce 861 primary
entries after the combined application wave. The full 1036-profile make check
passes; validation.md links its complete transcript. M4 remains in progress.
