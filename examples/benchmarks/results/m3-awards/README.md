# m3-awards validation

Recorded 2026-10-04. The ports retain the original combinations, shared totals, tier priority,
stable/anti-stable quicksort and first-occurrence score removal. All 100 source
inputs agree with GHC, an independent combinations oracle and the pinned FAST
template. Normal preserves FAST 2,000 iterations. Nine semantic checks pass
all ten configurations at both levels. Large is not universally checked.

[All 48 final primary cases](correctness.tsv) pass smoke/normal
on four Rune engines at both optimization levels and four managed native hosts.
The final matrix compiles canonical suite paths, source order and inputs.

Count archives retain complete samples, source/input/tool snapshots and
configuration identities. Allocations and applicable instruction comparisons
agree. Instrumented times are not headline timing evidence. Initial resolver
races are retained in [the tooling record](../m6-resolver-isolation/README.md).
