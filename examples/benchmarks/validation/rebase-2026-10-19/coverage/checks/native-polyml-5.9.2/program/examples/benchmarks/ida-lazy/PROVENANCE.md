# ida-lazy provenance

### Algorithm and workload

Solve deterministically shuffled sliding-tile puzzles by the source
iterative-deepening/branch-and-bound search. Retain Manhattan bounds, forced
single moves, persistent movable/fixed tile lists, reversed hole histories,
the source best-solution tie rule and its two-level branch partitioning.
Do not substitute the independent breadth-first checker for the benchmark.

### History, authorship and variants

[The Hartel ida source](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/hartel/ida) is pinned at
b7391df4540ac8b11b35e1b2e2c15819b5171798. No individual author or separate
program notice is stated in its generated module; preserve the complete
Main.hs, Makefile, FAST/NORM/SLOW fixtures and parent Fast2haskell shim.
The collection name alone does not establish individual program attribution.
No external dataset is required.

Names ida-lazy and ida-strict distinguish the finite tile-list policy.
Both are sequential ports of this pinned source: its sandwich helpers use
the compatibility shim's no-op miraseq, not an active parallel primitive.
No runtime/compiler prerequisite is introduced by preserving those helpers'
sequential result computation and source constructor matching.

### Translation and demand

The lazy variant memoizes finite tile-list heads/spines and their field
transformations; strict evaluates these finite lists when requested.
Coordinate pairs and bounded numeric metadata are strict SML values. Search
records, bounds, distances, board roots, solution fields, branch-control
streams and hole histories retain explicit memoized delays in both variants.

Preserve source reversed random-prefix consumption, list rotation and stable
partition ordering. Shared delayed recursive partition pairs avoid testing each tile twice;
retain the source paired-result structure rather than allocating a separate
list of tagged classifications. Keep the source right-recursive total Manhattan distance rather
than introducing a strict accumulator. The shim's fold annotations are no-ops;
best-candidate folds defer their accumulator. Do not demand a branch entry
before an already achieved cutoff, or calculate an unused pruned fold before
the source sandwich branch. Collect matches both solution constructors before
building its lazy best-state/count fields.

All arithmetic fits signed 31-bit integers for these profiles. The generator
is seed six with multiplier 4663 and modulus 46199, adding one after remainder.
Its largest intermediate product fits that bound. A hundred random shifts are
applied in the source's reversed generation order; no random-distribution or
initial tile-order replacement is made. Every repetition computes a fresh
configuration and search; no result cache across repetitions is introduced.
Read/validate arguments and the result reference once outside the loop, replacing
the original repeated getArgs lookup inside its IO repetition.

### Inputs, checks and profiles

Smoke selects one repetition at width two and height four, reducing FAST's
1500 repetitions. Normal retains 600 repetitions at width three/height four;
large retains 3000 at the same dimensions. Keep shuffle length 100, branch
delta seven and worst bound 101. These are deterministic work bounds, not
wall-clock searches. Source solutions report bound/partitions 12/13 for smoke
and 22/994 for normal and large.

Validate each original two-line result, including exact ordered shuffled tiles,
against a reviewed original reference. Additionally replay the complete solution
history, check adjacent legal moves and solved tile positions, and compare the
move count with the final bound and zero residual distance. Return repetitions
and checked source bytes instead of printing every repeated result. This
additional checker has a separate list traversal cost; the kernel remains
the original persistent list search. All checks are exact.

Original GHC 9.4.7 matches the supplied FAST/NORM/SLOW fixtures. Export-only
observers record 37 full configurations, bounds, partition counts and solution
histories. An independent model checks ordered shuffles and all legal complete
paths; independent breadth-first search verifies optimal lengths for 33 small
cases. The twelve-tile normal optimum is an original-reference agreement, not
an independently exhaustive breadth-first proof.

The 108-check target covers both variants, source observations, reversed PRNG
prefix, tie/cutoff/constructor demand, solved-state field avoidance, zero work,
finite-list policy and incorrect-result rejection. Full final SML large
repetitions remain unrecorded unless listed in validation. Private calibration
and earlier demand refinements are development scopes, separate from final
registered source identities and canonical checks.

### Literature and diagnostic interpretation

Hartel and Langendoen's 1993 collection paper supplies translated-workload
context, not individual authorship evidence or measured claims about this port.
The pinned program and shim establish the particular bound, tie, partition and
evaluation rules. Exact original paths and independent checks support the
recorded behavior.

Investigate search-tree allocation, persistent list updates, lazy finite fields,
shared classifications, higher-order candidate folds and demand at cutoffs.
These are source-based hypotheses. Counts and timings must be interpreted in
their recorded engine, instrumentation and fresh/repeated process modes; they
do not by themselves identify a compiler or collector cause.
