# Column-pruned cryptarithm search

Recorded 2026-10-16. Two imports bring the catalogue to 252 programs and
750 profiles. [All 56 smoke/normal cases](correctness.tsv) pass on four Rune
engines at both levels and all six managed native hosts. Ten semantic checks
pass all ten configurations at both requested levels. Eight normal count samples
pass and applicable comparisons agree. Counts remain unbudgeted and separate
from headline timings.

The shared functor retains ordered StateT/list search, remaining-digit deletion,
dictionary order, column selection, units-digit pruning and carries. Need
memoizes state/value cells and consumes the first answer; the strict policy
materializes finite alternatives. Small finite word preprocessing, explicit
suspension representation and per-call output validation are documented changes.
Normal 300 and large 1,500 preserve the published repetition settings. Source
iteration-dependent word construction and the shared initial digit state remain
intact. Every complete rendered mapping is checked before its bytes are consumed.

An independent exhaustive 10! assignment search confirms a unique solution.
GHC observers establish the full solution state and first-answer dictionary
order. Original smoke, FAST, normal and large runs agree with the independent
mapping and all available pinned stdout fixtures. Program and transformers
sources retain individual authorship, notices and identities. The reference
uses transformers 0.5.6.2, whose State module re-exports the lazy implementation.

Semantic checks cover both full searches, complete rendering, ragged transpose,
first-only deletion, smaller puzzles, carry rejection, leading-zero acceptance,
and non-demand of unused digit lists and choice tails. The different exhaustive
permutation algorithm in cryptarithm1 remains a separate import commitment.
No historical cross-language speed claim is transferred. Large SML execution
is claimed only for recorded cases. M3 remains in progress.
