# SET circuit simulator: exact preprocessing and numerical traces

Recorded 2026-10-16. The complete smoke/normal matrix has 56 cases: 53 pass and
three native legacy 64-bit SML/NJ cases return incorrect results. Every Rune engine
passes both optimizations/profiles/variants; all five other native hosts pass.
The incorrect default-setting rows remain in coverage.tsv and have no accepted
timing. Separate 64 MiB nursery replays pass all three failed cases without
changing suite defaults. The existing real/GC report is a supported diagnostic
hypothesis, not a reduction proving this application's cause.

The 118-case semantic/negative set runs on ten configurations twice, with Rune
O0/O2 and native defaults. There are 2329 passes and 31 failures across 2360
assertions. Three subnormal conversion probes fail per SML/NJ host/run, six
explicit integral-nearest probes fail per Poly/ML run, and one additional legacy 64-bit
workload assertion fails under default allocation. All four Rune engines, MLton
and MLKit pass every assertion. Complete summaries/outputs retain each result.

The initial bit encoder's nearest-mode conversion made four correct Poly/ML
conversions look wrong. The encoder now truncates its exactly integral operand;
separate native nearest regressions and the local minimal report preserve the
defect. The benchmark kernel has no Real.toLargeInt call. SML/NJ's subnormal
fromManExp behavior reproduces the existing report outside this workload's
normal/zero conversion domain. All original diagnostics remain separately tagged.

Eight normal count samples agree under the execution-model rules, including
allocation across all Rune engines. Existing budgets are unchanged; new profiles
are unbudgeted. Five serial native smoke samples validate adapters; one legacy 64-bit
lazy correctness precheck rejects an incorrect result before sampling. Counts,
resource preflights and single-sample diagnostics remain separate from headline
timings.

The unmodified GHC reference matches all Done fixtures. Full traces and a separate
Fraction/mutable-matrix/binary64 model agree exactly on 371/2913/11315 rows with
170/912/1314 extra events. Both original and independent preprocessing agree on
all exact matrices and binary64 conversion bits. Rune's conversion boundary plus
all three preprocessing sets provide 3960 exact bit checks. The independent
minimum CDF margins exceed 8.56e-6 for normal/large. Exact times/event records,
labels, dimensions and EOF accompany current/voltage bounds; deliberate numerical
perturbations and malformed/truncated/extra results are rejected.

All source parameters and input bytes remain pinned. Numerical payloads use
memoized or eager evaluation while rational conditional branches, RNG state/head
sharing and trace control remain lazy. GEN17 formatting and quoted-length counting
preserve consumer work with an explicit formatter replacement. Exact arithmetic,
SI parser quirks, all seven element classes, zero temperature, background charge
and huge seed behavior have recorded checks. The source inversion/simulation
algorithms are retained. No compiler/runtime prerequisite or host workaround is
added. Large whole-program SML validation is limited to recorded checks. M4
remains in progress.
