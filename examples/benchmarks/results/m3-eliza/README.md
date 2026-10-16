# Eliza conversations and cyclic state

Recorded 2026-10-16. Both variants pass all 56 smoke/normal combinations across
Rune's four engines at O0/O2 and all six managed native hosts. All 60 semantic/
negative checks pass all ten configurations twice, with Rune O0/O2 and native
defaults. Eight normal count samples agree under Rune's execution-model rules,
including allocation across all four engines. Existing budgets are unchanged;
these new profiles are unbudgeted. Six serial native smoke samples validate
MLton, SML/NJ and Poly/ML adapters. Counts and one-sample adapter diagnostics
remain separate from headline timings.

The unmodified original matches all three stdout fixtures. An independent
ordered-key/counter model agrees on all 20 complete conversation prefixes and
every original length through 65000 iterations. Extra full sessions cover repeated
inputs, cyclic key rotation, trailing-I conjugation, empty suffix defaults,
fallback and punctuation. Tests check complete responses in both variants,
exact cyclic sharing, demanded/unused suffixes and wrong/truncated/extra output.

Memoized cyclic queues and initial state are shared, while conversations are
recomputed on every iteration. Lazy response/next-state fields avoid constructing
an unused final key table; strict finite candidates/output construct eagerly.
Strict input loading, finite word lists, string representation and fused candidate
list layers are documented adaptations. Smoke covers one prefix cycle, normal
preserves 13000 iterations and large retains 65000 with reference evidence.
Additional large SML validation is claimed only where recorded.

Original source/input notices, observers, independent model, complete results,
source identities, all 45 inventory fixtures and the full clean 861-entry replay
are retained. M3 remains in progress.
