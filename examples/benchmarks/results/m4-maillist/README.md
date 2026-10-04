# Mailing-label application

Recorded 2026-10-04. Paul Hudak's application retains paragraph parsing,
four-line labels, 30-label pages, exact LaTeX output and every separate
append-file open/write/close. M4 remains in progress.

[All 24 primary smoke/normal cases](correctness.tsv) pass on four Rune engines
at both optimization levels and four managed native hosts. Complete output
fixtures for all three input profiles agree with original GHC and an independent
page formatter. Normal preserves the original 100 iterations. Full output
validation and readback costs are explicit. Large SML execution is not
universally claimed.

Eight boundary checks pass all ten configurations at both levels: line endings,
leading blanks, empty documents, padding, truncation, the 35-character warning
boundary and 31-label page rollover. The first sandboxed 32-bit SML/NJ attempt
terminated with SIGSYS; its permitted rerun passes. Raw attempts are retained.

Separate count samples preserve configuration, source, input and tool identities.
Allocation counts agree across all four Rune engines; applicable instruction
comparisons agree. Instrumented times are not headline timing evidence.
