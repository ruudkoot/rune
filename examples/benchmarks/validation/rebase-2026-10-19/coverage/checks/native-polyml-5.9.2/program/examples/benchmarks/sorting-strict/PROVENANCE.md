# sorting-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`,
`spectral/sorting/Main.hs`, `Sort.hs`, `Makefile` and `common/NofibUtils.hs`.
Original author and individual program grant are unstated. Sort.hs repeatedly
credits an abbreviated Meira thesis; the [literature note](../literature.md#sorting-source-attribution)
records a bibliographic candidate and the remaining ancestry uncertainty.
Retain all source comments, module data, fixtures, build settings and hashes.

## Workload, algorithms and variants

Main composes EIGHT sorting algorithms with SEVEN intermediate reversals.
Its foldr composition runs right-to-left: treeSort2, reverse, treeSort, reverse,
quickerSort, reverse, quickSort2, reverse, quickSort, reverse, mergeSort, reverse,
insertSort, reverse, heapSort. Every stage remains present, with descending
intermediate inputs affecting its work. Separate algorithms inside this one
upstream executable are not collapsed into one sorting implementation.

Preserve two-filter versus partition quicksort, accumulated quicker-sort
partitions, reverse-prefix insertion, natural-run splitting, right-fold run
merging with x:y equality, foldr BST, specialized Twig2 leaves and binary-indexed
heap insertion/mix. Keep guard order and repeated comparison calls before
compiler optimization. Equal-prepending run construction means global mergeSort
is not described as stable merely because its merge emits left first.

The two variants share a generic SML97 functor, using memoized or eager sequence,
label and child fields. Reversal preserves head suspension while traversing
spines. A shared pair records partition results. Explicit cells, generic tree
constructors and portable list helpers are representation/library adaptations.
Lexicographic row comparison uses Unicode scalar order, matching Haskell Char.
Heap indices and selected loop counts fit 31 bits. Source hashing explicitly
wraps signed 64-bit GHC Int semantics through Word64; the repetition total is IntInf.

## Profiles, acquisition and checking

Smoke reads the original Main.hs once (31 lines). Normal reads original Sort.hs
600 times (140 lines), and large retains 3,000 Sort.hs repetitions. Original FAST's
600 Main.hs repetitions remain provenance. Datasets are the exact pinned program
source files, including comments/notices, rather than a separately acquired corpus.
The file is reopened on EVERY repetition as in Main. Portable strict UTF-8
acquisition and copied line buffers replace lazy text IO; getArgs/path parsing
occurs once in the driver, a documented change.

The complete ordered final row sequence is compared with a reviewed UTF-8
fixture before nofib's hash/LF calculation. Validation additionally materializes
each final row and consumes all hashes in a checked total, replacing repeated
printed hashes. This extra acquisition/forcing/checking is included in metrics.
It does not force intermediate character payload beyond the source pipeline.

Unchanged GHC and independent Unicode sorting agree for every selected profile
and all pinned hash fixtures. Tagged-key GHC observers establish per-algorithm
tie order and full pipeline order. Forty semantic checks cover all lists of
length 0..5 over [-1,0,1], each algorithm in both variants, the full pipeline,
tagged ties, unneeded right subtree demand and repeated guard callback calls.
Large SML execution is claimed only for recorded cases.

## Runtime questions and references

Comparator/closure specialization, tree and row sharing, natural runs, descending
intermediate data, repeated prefix scans, allocation, file IO and added validation
are source-based diagnostic hypotheses until established by measurements or IR.
Counting-callback tests preserve translated control flow; actual compilers may
optimize pure comparisons. Original Haskell is a correctness reference; compiler
reports use identical SML sources.

Source-specific ancestry remains in the retained Meira comments and the shared
literature note. See Partain's nofib suite paper, the existing functional-list
sorting references and [the pinned modules](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/sorting).
No unread-thesis finding or historical timing result is transferred to this port.
