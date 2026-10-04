# Mutable Stack workloads

Recorded 2026-10-04. Fold and push/pop retain separate names and share the
reviewed linked-list/cached-length library replacement. Original normal inputs
are preserved: 2,500,000 folds of 100 integers and 100,000,000 push/pop pairs.
Source Sys.opaque_identity result consumption becomes checked SML aggregation;
representation, validation and accumulator costs are explicit.

[All 48 primary cases](correctness.tsv) pass smoke/normal on four Rune engines
at both levels and four primary managed native hosts. Original OCaml observers
agree with independent arithmetic and final stack invariants. The replacement
library matches pinned OCaml 4.14.1 source; its complete notice is retained.

Nine semantic checks pass nine configurations at both levels. ML Kit crashes
on the final test source paths; scratch paths with the same operations/checks
previously passed there. The [failure report](../../validation/mlkit-stack.md)
distinguishes observed behavior from its unisolated cause. All eight additional standalone smoke/normal cases pass on ML Kit and
32-bit SML/NJ, bringing recorded successful cases to 56. Source code is kept for reproduction.

Complete count samples, metadata and source/input/tool identities are retained.
Allocations and applicable instruction comparisons agree. Instrumented times
are not headline timing evidence. Large SML validation is not universally
claimed. M5 remains in progress.
