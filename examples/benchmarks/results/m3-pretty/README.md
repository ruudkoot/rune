# Metadata-driven pretty printing

Recorded 2026-10-16. Both variants pass all 56 smoke/normal cases across Rune's
four engines at both levels and all six managed native hosts. All 42 semantic/
negative checks pass all ten configurations twice, with Rune O0/O2 and native
defaults. Eight normal count samples agree; existing budgets are unchanged and
these new profiles are unbudgeted. Six serial native smoke samples validate
MLton, SML/NJ and Poly/ML adapters. Counts and single-sample diagnostics remain
separate from headline timings.

Unmodified output agrees with the pinned 343-byte fixture. Parameterized original
and independent main-document layouts agree at empty/one-word cases, exact fit
boundaries, smoke/normal and 5000-word scaling. Eleven original combinator edge
outputs agree with independent bytes. Both SML variants match all main fixtures,
including the 30043-byte large output in a standalone Rune preflight. This is
not canonical large validation across all configurations.

Retain whole-result/field sharing, lazy short-circuit decisions and unused
alternative non-demand. Strict metadata, CharSeq and output nodes remain eager,
while both styles retain the finite boundary on the cyclic word-input stream.
The source ppCat keeps its word line long at width 80; do not replace it with
wrapping or normalize tabs, trailing spaces, empty strings or embedded newlines.
Every output byte and EOF is validated. Negative checks reject changed bytes,
space-for-tab substitution, truncation and extra output.

Required APIs, bounded ASCII/count assumptions, output adaptation, notices,
original sources, edge fixtures, models and every raw sample are documented.
No prerequisite compiler/runtime feature or universal large execution is
introduced or claimed. M3 remains in progress.
