# Lisp-like Boyer theorem rewriting

Recorded 2026-10-16. Both variants pass all 56 smoke/normal cases across Rune's
four engines at both levels and all six managed native hosts. All 25 semantic/
negative checks pass all ten configurations twice, with Rune O0/O2 and native
defaults. Eight normal count samples agree; existing budgets are unchanged and
these new profiles are unbudgeted. Six serial native smoke samples validate
MLton, SML/NJ and Poly/ML adapters. Instrumented counts and single-sample adapter
diagnostics remain separate from headline timings.

Complete original output agrees with the upstream fixtures at 60/600/3000.
Export-only observers expose the input, full rewritten term and LUT bucket
counts for 1/2/60/600. An independent proper-tree/dictionary implementation agrees
on every byte and checks all 32 truth assignments for each normalized formula.
Lazy and strict SML compare complete normal forms in supplemental checks.
Normal600 preflights validate every theorem input in each variant.

Preserve all 106 exact rule strings, space-only tokenization, trailing empty
tokens, missing-close acceptance, non-cons selectors, first-list prefix
unification and the accepted missing-RHS rule. Do not repair or normalize them.
Binary Lisp terms, association lists, unbalanced LUTs and ordered rule buckets
retain their lazy/eager representations. Runtime-deferred immutable caches
preserve CAF-like parsing and statement behavior without initialization during
native export. Each benchmark theorem Boolean is validated before reporting.
Complete-form tests add forcing only to validation, not the timed workload.

Provenance, source notices, raw/adapted observers, independent model, inputs and
all raw samples are retained. No prerequisite compiler/runtime feature or
universal large SML execution is introduced or claimed. M3 remains in progress.
