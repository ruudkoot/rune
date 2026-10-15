# ANSI stream composition

Recorded 2026-10-15. [All 56 canonical smoke/normal cases](correctness.tsv)
pass on four Rune engines at both optimization levels and all six managed SML
hosts. Fourteen semantic checks pass all ten configurations at both levels.
Normal retains 400 composed programs; large retains 900. Original GHC,
independent byte-transducer modeling and all pinned upstream fixtures agree
exactly. The original FAST size 150 and small 0/1/2/3 cases are also checked.
Large SML execution is not universally claimed.

The final CPS translation shares the program continuation and applies an EOF
callback only when that branch is selected. A GHC demand observer confirms the
prefix is available without invoking the callback; the new regression test
rejects the old draft. Literal control bytes remain fixtures, rather than being
sent to a live terminal by the portable driver. Every emitted byte is checked.

Final allocation and applicable instruction comparisons agree across all four
Rune engines. For normal input the memoized port allocates 24,074,485,624 bytes
and 636,744,783 objects cumulatively; the strict port allocates 8,787,690,120 bytes
and 173,474,231 objects. Recorded count-process maximum RSS ranges are about
10–131 MiB and 280–292 MiB respectively. RSS and cumulative allocation measure
different quantities. Raw samples retain all source/input/tool identities and
runtime settings; instrumented times are not headline timing results.

`intermediate-counts/` is an interrupted draft collection. Its eager EOF-callback
construction violates source demand, and strict -O2 attempts exhaust the 4 GiB
address-space limit. Its memoized allocation was 129,427,556,344 bytes. These
artifacts, the exact old kernel and its failing new regression test are retained
to explain the correction; they are not accepted benchmark measurements or a
separately named workload. Final source keeps the original input sizes and limits.
M3 remains in progress.
