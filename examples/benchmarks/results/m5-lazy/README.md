# Sandmark lazy and CPS workloads

Recorded 2026-10-03. Three ports add lazy primes, independent lazy-list heads,
and the CPS sequence pipeline. The catalogue contains 190 programs and
564 profiles. M5 remains in progress for the remaining sequential collection.

[The ledger](correctness.tsv) records all 72 required smoke/normal runs:
four Rune engines at two optimization levels, plus four primary managed
native hosts. Complete stdout, compilation logs and available compilation
identities are retained. Original OCaml results agree with independent
trial division, list length/head identities, and weighted-square sums.
No universal large SML execution is claimed.

Eight lazy semantic checks preserve strict prime heads, memoized tails, extra
demand caused by take, and independent heads sharing the original zero.
Seven CPS checks cover empty/skip/yield/done, state advancement, inclusive
bounds and exact sums exceeding 31 bits. Both targets pass all ten managed
configurations at both Rune levels. The initial CPS test's unconstrained empty
reference was rejected by SML/NJ; its explicit int-list annotation fixes test
portability without changing the benchmark. The failed transcript is retained.

The CPS port preserves the actual callback pipeline and unfolder record,
specializing its used state/payload/continuation types for SML97. IntInf
preserves selected original 63-bit values while changing representation;
the translation and optional original GC observer are documented. Lazy-list
validation traverses the allocated spine without forcing unused heads; its
additional traversal and retention costs are explicit.

Separate count archives retain complete samples, compiler/configuration
metadata and source/input/tool snapshots. All four engines' allocation counts
and applicable instruction comparisons agree. Instrumented times are not
headline timing results. Compiled payloads and disposable work directories
are excluded. The complete acceptance transcript is recorded in validation.
