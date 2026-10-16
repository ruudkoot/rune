# Demand-sensitive secretary simulation

Recorded 2026-10-16. Two imports bring the catalogue to 281 programs and
837 profiles. All 56 selected smoke/normal cases pass across Rune's four
engines at both levels and all six managed native hosts. All 145 semantic/
negative checks pass all ten configurations at both levels. Eight normal
count samples agree across Rune engines. Existing budgets remain unchanged;
these new profiles are currently unbudgeted. Six serial native smoke samples
validate MLton, SML/NJ and Poly/ML adapters. Instrumented counts and single-sample
diagnostics remain separate from headline timings.

The exact random-1.1 source compiles with the unmodified nofib program and
reproduces its pinned probability fixture. Original count-expression observers
and an independent full-permutation/set model agree through 50000 trials.
Separate source observers agree on 60 full RNG transitions, six complete
permutations, 30 minimum lazy/complete strict draw counts and five general
Integer ranges through signed 10^50. Every selected normal trial count is
validated against original and independent references.

The lazy port preserves raw random streams, linear nub membership, finite
take100, shared maximum/search prefixes and early stopping. The strict port
materializes the complete permutation through an explicitly bounded producer.
Both retain trial map/filter/length and binary64 probability division. The
source's two fixed-width states remain Word32; range accumulation remains
IntInf. Each call starts the original seeds afresh. Full count/probability
checks and EOF consume the results. Numerical/negative tests reject changed
counts, perturbed/nonfinite probabilities, truncation and extra rows.

Smoke uses 50 trials, normal 500, and selected large retains the original
5000. Current-kernel 500 and 5000 preflights on Rune O2 validate both success
vectors. The 5000 preflights are kernel count-vector checks, not canonical
large-profile validation on every configuration. Their bounded resource
calibration is not a headline performance comparison. The larger 50000 input
has complete original/independent references and remains unselected.

The separately labeled intermediate-calibration used arbitrary-precision RNG
states before the final helper retained source Int32 width. That preliminary
run was deliberately stopped before completion; its SIGTERM, source/bytecode
identities and stop reason are retained. It is neither an accepted measurement
nor a compiler failure. No hidden package replacement, alternate RNG stream,
prerequisite compiler/runtime feature or universal large SML execution is
introduced or claimed. M3 remains in progress.
