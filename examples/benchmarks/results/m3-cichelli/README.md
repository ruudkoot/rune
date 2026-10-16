# Cichelli serial perfect-hash search

Recorded 2026-10-16. Both variants pass all 56 smoke/normal combinations across
Rune's four engines at O0/O2 and all six managed native hosts. All 36 semantic/
negative checks pass all ten configurations twice, with Rune O0/O2 and native
defaults. Eight normal count samples agree under Rune's execution-model rules,
including allocation across all four engines. Existing budgets are unchanged;
new profiles remain unbudgeted. Six serial native smoke samples validate MLton,
SML/NJ and Poly/ML adapters. Counts, bounded preflights and one-sample diagnostics
remain separate from headline timings.

The unmodified original reproduces all three fixtures: FAST 6/NORM 60/SLOW 300
produce 507/5070/25350 bytes with no line separators. An independent set-based
search agrees on both parity problems and all seven prefix cases. Odd indices
add the first keyword again and fail with 324 leaves. Even indices find the first
full assignment with 113994 leaves. The independent traversal visits 631/116083
states respectively; these are not the source's feedback leaf counts. The full
witness assigns 17 end characters and maps 22 keywords to the interval 4..25.

Keep identity frequency ordering, right-fold histogram/partition order, original-
left-list union membership, association precedence, inclusive weights 0..17 and
the fixed range bound 22. Both variants short circuit at the first successful
result. Lazy evaluation memoizes count arithmetic/candidate construction; strict
evaluation materializes finite candidates and combines counts eagerly. Search
result spines stay memoized in both, preserving pruning. Finite key preparation
uses strict lists. These explicit representation choices are part of the port.

Every selected integer/count fits signed 31-bit Int. Each runtime index recomputes
its search; no parity result is reused as a repeated-run answer. SML-generated
index files retain exactly 1..n, with source 6/60/300 work counts. Complete byte/EOF
checking consumes every status and witness before accepting a result. Large
preserves repetitions of the fixed dictionary; large SML validation is claimed
only where recorded.

Original data/notices, primary bibliographic metadata, observers, independent
model, raw results, source identities and all 45 inventory checks are retained.
No prerequisite compiler/runtime feature is introduced. M3 remains in progress.
