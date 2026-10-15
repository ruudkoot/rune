# Repeated spectral Fibonacci heaps

Recorded 2026-10-15. [All 56 final smoke/normal cases](correctness.tsv) pass
on four Rune engines at both levels and all six managed native SML hosts.
The [attempt ledger](correctness-attempts.tsv) retains the initial sandbox SIGSYS
termination of 32-bit SML/NJ separately from its successful unsandboxed run.

Both variants preserve the spectral source's 200 repetitions and its original
500/3,500/16,000 sizes. They share the reviewed heap kernel with the single-run
GC variants, while retaining different names, drivers and upstream provenance.
Every repetition compares both sorted outputs and validates ordering, complete
histogram, length and sum. Original GHC runs and independent histogram generation
agree for all selected profiles. The shared kernel's nine semantic checks were
validated across all ten configurations at both levels in the preceding import.

Count archives retain complete raw samples, configuration metadata and source,
input and tool identities. Allocation and applicable instruction comparisons
agree across Rune engines. Instrumented times are not headline timing results;
these 200 repetitions do not imply steady-state execution. Large SML execution
is not universally claimed. All 35 inventory tests pass. M3 remains in progress.
