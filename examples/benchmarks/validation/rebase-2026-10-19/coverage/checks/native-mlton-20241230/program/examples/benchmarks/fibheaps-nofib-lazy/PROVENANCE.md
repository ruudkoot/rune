# fibheaps-nofib-lazy provenance

The nofib revision is `b7391df4540ac8b11b35e1b2e2c15819b5171798`,
`spectral/fibheaps/Main.lhs` and `Makefile`. Chris Okasaki's July 1995
correspondence, source comments, library dependencies and byte identities are
retained under `upstream/`; no individual license grant is stated. All inputs
are generated in source; independent histogram fixtures have no external data.

This variant runs the same mutable-array and functional degree-consolidation
comparison as the GC version, 200 times per invocation. Preserve its FAST/NORM/
SLOW sizes 500/3,500/16,000 as smoke/normal/large, all 200 repetitions, and the
first seed 1967 followed by `(77*seed+1) rem 1024`. These driver parameters differ
materially from GC's single 300,000-element run, so both provenances and names
remain separate. The `-nofib` suffix distinguishes the spectral profile variant
from `fibheaps-lazy` and `fibheaps-strict`.

The shared SML97 functor preserves cached size/minimum, binomial trees, degree
tags, bag forests, traversal order, tie rules and both deletion algorithms.
See [the GC port](../fibheaps-lazy/PROVENANCE.md) for the algorithm, demand and
representation audit. Memoized and eager finite structures are separately named.
Portable arrays replace the encapsulated ST array and accumArray operations.
Inputs and selected scalar sums fit 31-bit integers. No arbitrary-width or
modular arithmetic substitution is needed.

The original forces its equality result with `seq` but does not print or reject
a false result. The driver consumes and compares both sorted streams on every
repetition and additionally checks ordering, a complete independent histogram,
length and sum. It loads the expected histogram once and copies its counters
for each repetition. Result reporting states repetition count, element count
and the per-repetition sum; it checks agreement without summing all repetitions.
Input generation remains within each repeated sort; immutable template loading
and validation overhead are documented adaptations. These are repeated
in-process workloads; fresh-process measurement wraps the entire invocation
and makes no steady-state assumption.

Nine shared semantic checks cover RNG prefixes, consolidation, forest orders,
ties and demand. Original GHC observers and independent histogram generation
provide expected results; large SML validation is recorded only when run.
Memo-cell retention, array lifetime, degree carries and compiler sharing are
source-based diagnostic hypotheses until measured. Algorithm reference:
[Fredman and Tarjan (1987)](https://www.cs.princeton.edu/courses/archive/fall03/cs528/handouts/fibonacci%20heaps.pdf);
Okasaki's retained correspondence describes this smaller persistent interface
and its amortization caveats. See the shared nofib and measurement survey.
