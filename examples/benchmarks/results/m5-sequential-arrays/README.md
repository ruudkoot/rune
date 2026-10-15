# Sequential Sandmark array kernels

Recorded 2026-10-15. Four array imports are validated alongside four new nofib variants
in the 229-program, 681-profile catalogue. [All 104 final cases](correctness.tsv)
pass smoke/normal on four Rune engines at both levels and five managed native
SML hosts. Twenty-one semantic checks pass those nine configurations at both
levels. Their raw reference streams cover 10,000 draws per seed/mode.

The [attempt ledger](correctness-attempts.tsv) retains a scratch-runner error
that treated the manifest's no-file marker as a filename, then the managed
32-bit SML/NJ arithmetic failures. Both profiles of all four ports raise the
same spurious Overflow on that host. An [independent checked probe](../../validation/smlnj32-random.md)
isolates a representable threshold expression; variable-maximum controls and
six other comparison configurations pass. The portable expression and reviewed
expected results remain unchanged. Failed cases cannot contribute measurements.
The additional scratch launcher's PASS labels in correctness-32.log mean that
it observed the expected host failure; per-configuration raw logs say PROGRAM FAIL.

Original OCaml kernels with result observers supply all three selected profile
results, including original large sizes. Independent Python sorting, column dot
products and repeated Bellman-Ford relaxation agree on smoke/normal. Sorting
checks every multiplicity and ordering; matrix drivers check complete cell
fixtures. Validation overhead, precomputed fixed-seed initialization and added
IntInf totals/Word32 fingerprints are explicit adaptations. Original notices,
OCaml Random source and complete LGPL 2.1/OCaml exception text are retained.

All four count groups agree on allocation and applicable instruction comparisons
across Rune engines, with raw samples and source/input/tool snapshots retained.
These instrumented times are not headline timing results. Large SML execution
is not universally claimed. M5 remains in progress.
