# Typed Boyer terms and recursive lemma graphs

Recorded 2026-10-16. Both variants pass all 56 smoke/normal combinations across
Rune's four engines at O0/O2 and all six managed native hosts. The first broad
run has 55 passes and one Rune O0 strict-smoke timeout at the default 30 seconds.
A documented 60-second strict-smoke override preserves the original FAST2 input
and all 100 repetitions. All four O0 engines pass the replay. The complete
60-attempt ledger retains the timeout; 56 final configuration/profile entries
pass. Normal retains NORM15 and the default 600-second limit.

Thirty semantic/negative checks pass all ten configurations twice, with Rune
O0/O2 and native defaults. They cover typed term equality without forcing cyclic
lemmas, attached-rule sharing, failed-environment bottoms, exact unification
argument lengths, source normal forms and wrong/truncated/extra form rejection.
The original/independent models agree on all nine variable inputs and all 32
truth assignments. Only X proves the theorem; its complete normalized form is
170284 bytes. All three original stdout fixtures are checked.

Eight normal count samples agree under Rune's execution-model rules; allocation
counts agree across all four engines. Existing budgets are unchanged and the
new profiles remain unbudgeted. Six serial native smoke samples validate the
MLton, SML/NJ and Poly/ML adapters. Counts, bounded preflights and single-sample
diagnostics remain separate from headline timings.

Both SML variants retain typed IDs, substitution, one-way matching, rule priority,
short circuiting and attached lemma streams. The strict variant eagerly builds
finite term/argument structure while recursive lemma graphs remain memoized.
Runtime variable files replace the source NOINLINE input dependency and permit
all source variable names. Every theorem is recomputed and its Boolean checked;
no previous proof result is reused as a repeated-run answer. Source data,
export-only observers, independent models, complete raw results and identities
are retained. Large SML execution is claimed only where recorded. M3 remains
in progress.
