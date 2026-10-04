# Shared GC/spectral CSP solvers

Recorded 2026-10-04. Complete source programs, all five algorithms, original
240 repetitions and fixed sizes 6/7/8 match across GC and spectral copies.
One memoized/strict implementation pair retains both provenances and the GC
reference heap configurations. Inventory classification checks source bytes and
all profile keys; changed kernels or inputs remain separate.

[All 56 final required cases](correctness.tsv) pass smoke/normal on four Rune
engines at both levels and all six managed native hosts. The
[attempt ledger](correctness-attempts.tsv) retains a rejected unconstrained driver
projection and the 600-second unoptimized stack timeout. A portable pair pattern
fixes driver typing; the strict normal profile records a 1,200-second override
while retaining FAST size 6 and 240 repetitions. Its retry passes. Other limits
remain unchanged.

Original GHC full ordered solution sets agree with independent permutation and
diagonal checks at sizes 0..8. Backmarking's special zero-variable result is
preserved. Every method/repetition validates its complete solution vectors,
adding payload forcing and checks to the source's length-only observation.

Nine semantic checks pass nine final-path configurations at both levels.
ML Kit's additional test compilation crash is [recorded separately](../../validation/mlkit-constraints.md);
standalone smoke/normal benchmarks pass there. Earlier scratch paths passed the
same checks on all ten configurations; the cause remains unisolated.

Final typed-driver count archives retain every sample and source/input/tool
identity; allocation and applicable instruction comparisons agree. Earlier
projection-driver counts remain labeled intermediate. Strict normal allocates
about 101.6 GB cumulatively while measured resident peaks remain about 260 MiB.
Instrumented times are not headline timing evidence. Large SML execution is
not universally claimed. M3 remains in progress.
