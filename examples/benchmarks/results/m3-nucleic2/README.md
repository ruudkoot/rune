# Nucleic2 validation and M3 closure, 2026-10-18

Four ports preserve the source's on-demand versus shared placed coordinates
and separately named memoized versus eager finite data. The suite contains
495 programs and 1437 profiles. This completes M3: all 92 suitable pinned
kernel/GC inventory paths have implemented smoke and normal profiles.
[Coverage](inventory-coverage.tsv) identifies every path, source identity and
registered variant. M4 remains in progress and M8 remains planned.

| Gate | Recorded outcome |
|---|---|
| Canonical profile matrix | 98 of 112 combinations pass; all 64 Rune combinations pass at O0/O2 across four engines, four variants and two profiles. |
| Raw attempts | All 116 are retained, including four earlier Rune smoke runtime timeouts replaced by the recorded override and successful reruns. |
| Host exceptions | Eight legacy SML/NJ domain errors; three development SML/NJ smoke loading timeouts; one development smoke allocation failure; two empty-log ML Kit smoke compiles. |
| Normal hosts | MLton, Poly/ML, SML/NJ32, development SML/NJ and ML Kit pass every normal variant. Legacy SML/NJ fails all four. |
| Semantics | Twelve complete groups each pass all 5081 assertions. A partial legacy group records 89 passes and 65 failures before an exception; ML Kit records no assertions and an empty compile log. |
| Normal counts | All sixteen allocation-count samples agree across applicable Rune engines; all four unchanged process-tree guards exit zero without intervention. |
| Final serial adapter diagnostics | Eight MLton/Poly/ML fresh samples and preflights pass; four legacy SML/NJ preflights fail and contribute no accepted timings. All twelve native compilations pass. |
| Repository acceptance | make JOBS=4 check exits zero, including all 498 compiler comparisons and seven-host runedoc/runeopt agreement. |
| Inventory | All 152 regression tests pass; the five pinned inventories account for 861 entries. Final bench-smoke and check-docs pass after the documentation/metadata updates. |

[Canonical outcomes](correctness.tsv) and [all attempts](correctness-attempts.tsv)
retain every configuration. Native hosts run once with host-default options;
O0/O2 are Rune levels. [Semantic groups](semantics.tsv) distinguish complete
and interrupted groups: 61061 passing and 65 failing assertions were recorded.
Unreached assertions are not passes.

## Source fidelity and independent checks

Retain nofib b7391df4540ac8b11b35e1b2e2c15819b5171798's historical source,
individual notices, MAIL and README. The pinned revision is recorded
in each benchmark's provenance and inventory; original identities accompany
the observer sources. Preserve Marc Feeley's source credit, Lennart
Augustsson's Haskell-port credit and Hartel's coordination role separately.
The source README's 2017 removal of historical files does not make those
files present in this pinned tree.

All 6624 binary32 database patterns agree with GHC and an independent Python
decoder. The complete search has 50 solutions, 1150 exact conformation choices
and 109800 coordinates. All four portable variants agree bit-for-bit with
each other. Their coordinates meet the reviewed benchmark-specific budget
against GHC; the largest absolute difference is 6.866455078125e-5.
The maximum differs by one binary32 ULP, within the stated relative bound.
Bit identity with original-language coordinates is not claimed.

Source work agrees exactly: 38496 candidates, 5596 accepted steps, 27000
first-constraint checks with 50 successes and 6000 second-constraint checks
with 50 successes. Every coordinate accepts its reference and rejects both
positive and negative four-budget perturbations after binary32 rounding.
Tests also cover nonfinite values, round-to-even, signed zero, ignored
coordinates, actual sharing and lazy demand. The tolerance was recorded before
comparison; it is an engineering validation budget, not a proved error bound
for the physical model.

Legacy unboxed/PrimIO builds have explicit facility blockers in the naming
map. Current GHC ignores the old STRICT pragma; complete source observations
agree with the default build. That ignored pragma is not equated with the
portable eager policies.

## Limits and host observations

Smoke retains three complete searches. Only shared-strict overrides its
runtime allowance from 30 to 120 seconds, retaining 1 GiB. Normal remains
25 searches with 600 seconds/4 GiB; large remains 125 with 3600 seconds/8 GiB.
The original GHC driver succeeds for all source counts and nonpositive
controls. No full large SML host matrix is claimed.

The development SML/NJ smoke records show three timeouts while loading the
kernel and one unable-to-map/unable-to-allocate failure under the 1-GiB
limit. Interactive loading combines compilation and eager initialization;
the failure phase remains unclassified. These are distinct from legacy
SML/NJ's domain errors. Empty ML Kit logs do not establish a cause.
The same development and ML Kit hosts pass every normal profile.

[Host diagnostics](../../validation/nucleic2-host-results.md) link related
repository bug reports without asserting that they prove this failure's
cause. A legacy-runtime diagnostic observes an invalid tiny real and a
nursery-size-dependent outcome. The valid kernel and numerical bounds are
unchanged. Old native compile failures can retain the runner's default
exit 0; actual exit capture remains an M8 tooling follow-up.

Fresh samples are serial, single-sample adapter checks, not headline
performance claims. SML/NJ exported-image compilation evaluates declarations
before export, so eager initialization can enter the build phase. Compilation
and fresh-process execution must be interpreted together.

## Evidence and reproduction

The archive contains complete raw text, fixture identities, source order,
build metadata, source epochs, count samples and reports. Compiled files and
cache directories are excluded. Pruned cache contents are not inventoried
individually; a dash hash in excluded-payloads.tsv denotes an excluded suffix
that was not opened. Earlier subjects and failed attempts remain separate.

Run make bench-check with BENCH_FILTER=nucleic2-, BENCH_PROFILE=smoke or
normal, and selected BENCH_CONFIGS. Run sh tests/benchmarks/check-nucleic2.sh
for the full semantic target. Use make bench-count with the normal profile
for allocation comparisons. The archived launchers record the exact commands,
versions and subjects. Incorrect results cannot supply accepted timings.
