# Polymorphic inference application

Recorded 2026-10-16. Both variants pass all 56 smoke/normal combinations across
Rune's four engines at O0/O2 and all six managed native hosts. All 74 semantic/
negative checks pass all ten configurations twice, with Rune O0/O2 and native
defaults. Eight normal count samples agree under Rune's execution-model rules,
including allocation across all four engines. Existing budgets are unchanged;
these new profiles remain unbudgeted.

Six final serial native smoke samples validate MLton, SML/NJ and Poly/ML adapters.
The first adapter attempt retained four successful samples and two SML/NJ compile
errors from an ambiguous tuple type. Explicit pair patterns resolve that portable
typing issue. Both attempts and their exact source snapshots remain; failed
compilation has no accepted execution sample. Counts and single-sample adapter
diagnostics remain separate from headline timings.

The unmodified original reproduces all three 200-line stdout fixtures. Complete
texts have 643/990/1404 bytes; an independent Word64 polynomial hash agrees with
each source signed result. A separate parser/Algorithm W model agrees on all 48
profile expressions modulo type-variable renaming, including parse/type failures.
Twenty-four additional original sessions pin shadowing, polymorphism, repeated
application and literal let-prefix behavior. Exact full output and independent
models provide different forms of evidence.

Both variants retain memoized parser/result-list spines and greedy cut pruning.
The strict variant computes data value fields and term/type constructors eagerly
along demanded spines; the lazy variant memoizes those values too. An initial
eager-spine prototype hit a 2 GiB process-tree guard and is retained separately
as an experiment, with its source snapshots. The corrected bounded pilot agrees
on all six full texts; both source 200-iteration normal computations also pass.
Those pilot measurements are correctness/resource diagnostics.

Association maps keep shadowed entries and duplicate substitution domains.
Composition shares one new binding; one-occurrence subtraction, source occurs
checks, partial arity behavior and failure short circuiting remain. Curried
state functions fuse administrative wrappers without substituting a different
inference algorithm. Strict input/identifier loading and portable character
streams are explicit representation choices.

Every iteration rereads opaque input, recomputes inference, and checks all bytes,
EOF and the expected 64-bit hash. Immutable initial environment/header setup may
be shared. No previous term or inferred type serves as a repeated-run answer.
All profiles keep 200 repetitions and the exact source files. Large SML validation
is claimed only where recorded. Exact sources/notices, observers, models,
experiments, raw results and identities are retained. M4 remains in progress.
