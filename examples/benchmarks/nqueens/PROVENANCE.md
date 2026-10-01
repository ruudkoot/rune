# nqueens provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/multicore-numerical/nqueens.ml`, executable `nqueens.exe`.
No individual author or notice is stated in the file. Sandmark's root
public-domain notice is retained in `LICENSE`; the original file is retained.
This is the sequential executable in a directory also containing a separate
parallel implementation; no Domainslib or multicore facility is needed.

Translate depth-first row search directly, preserving the zero-based column
loop, shared immutable board suffixes, short-circuit conflicts, and mutable
sibling count. Explicit SML tail recursion replaces OCaml's for loop. The
count is consumed rather than formatted as a human-readable sentence.
There are no external inputs or seeds. Selected counters fit signed 31-bit
integers; no OCaml wrapping arithmetic is exercised by these profiles.

Smoke size 4 gives 2, normal size 10 gives 724, and large preserves the
upstream default size 13 giving 73712. All three are in the original source
comment and agree with the unchanged OCaml program. nofib queens counts
the same mathematical solutions through level generation, with distinct
lazy and strict retention; those are different algorithms/workloads, not
duplicates. Search, recursion, board sharing and local mutable counters are
source-based hypotheses. See [the Sandmark literature](../literature.md).
