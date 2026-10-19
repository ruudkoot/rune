# OCaml random reference streams

Generated from OCaml 4.14.1, `stdlib/random.ml` at revision
`99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93`. The installed reference source
matches that pinned source byte for byte. Each file contains 10,000 draws from
a fresh default, seed-42 or seed-512 state. Modes are raw bits, bounded integer
1, bounded integer 1,000,000,000 (exercises rejection), and real in [0,100).
There is no external dataset. Files contain generated scalar values.

The [observer and state derivation](../../../../../rune-benchmark-results/m5-sequential-arrays/reference-observers/)
record the exact acquisition code. Integer comparisons are exact; floating-point
checks permit absolute error 5e-14 plus relative error 1e-15. A deliberately
perturbed result must fail that bound. See the [port provenance](../../../../examples/benchmarks/quicksort/PROVENANCE.md)
for original library authorship, notices and the precomputed seed-state choice.
