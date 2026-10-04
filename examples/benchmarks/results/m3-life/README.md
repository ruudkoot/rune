# nofib Life variants

Recorded 2026-10-04. The two ports preserve the list-grid algorithm, zero
border, memoized versus eager cells and adjacent-generation fixpoint stopping.
M3 remains in progress.

[All 48 primary smoke/normal cases](correctness.tsv) pass on four Rune engines
at both optimization levels and four managed native hosts. The selected smoke
uses a nonempty initial pattern at size 15. Complete displays agree with the
original GHC observer and an independent synchronous array-grid oracle at
sizes 5/15/27/29. Large SML execution is not universally claimed.

Seven semantic checks pass nine configurations at both levels, covering center
cell demand, synchronous blinker steps, stop indices and lazy/strict agreement.
The paired ML Kit compiler crash is recorded in
[the failure report](../../validation/mlkit-life.md). No alternate golden or
source workaround is introduced.

Separate count samples preserve configuration, source, input and tool identities.
Allocation counts agree across all four Rune engines; applicable instruction
comparisons agree. Instrumented times are not headline timing evidence.
