# Three-state arbitrary-precision pi

Recorded 2026-10-16. One import brings the catalogue to 273 programs and
813 profiles. All 28 smoke/normal cases pass on Rune's four engines at both
levels and all six managed native hosts. Thirteen semantic/negative checks
pass all ten configurations at both levels. Four normal count samples pass
the combined comparison with unchanged budgets. Three serial native smoke
samples also validate MLton, SML/NJ and Poly/ML adapters. These single-sample
diagnostics and instrumented counts are separate from headline timings.

The port retains the three transformation components, both extraction
quotients, separate accumulator additions, tuple-work order and exact block
layout, including the zero-count convention. Every emitted character is checked.
Zarith becomes SML97 IntInf with truncating quotient semantics. The general
four-coefficient Zarith program and optimized nofib versions remain distinct.

Complete original outputs through 10,000 digits agree with independent
high-precision Gauss-Legendre pi and separate block formatting. The initial
reference script's partial-block slicing error is retained as a superseded
harness attempt; the corrected complete replay passes every reference case.
Normal 128 digits follows bounded resource calibration. Larger exploratory
sequences are incomplete/time-limited and contribute no measurements; their
buffering/progress transcripts are retained without assigning a compiler bug.

Source/library identities, author bytes, notices, raw validation/count records,
complete semantic logs and original/independent fixtures are retained. Validation
and input costs are explicit. No prerequisite compiler/runtime feature or
universal large SML execution is claimed. M5 remains in progress.
