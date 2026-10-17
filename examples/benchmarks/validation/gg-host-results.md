# GRIP graph host diagnostics

The portable renderer and checker retain the original workload and canonical
host configurations. Separate graph mathematics, input/ordering checks and
output-checker failures in their ledgers.

A small checker-only probe reproduces a discrepancy on native 64-bit legacy
SML/NJ 110.99.9 and development SML/NJ 2026.2 even for an empty character stream.
The expected forward and combined polynomial states are both Word64 zero, but
a diagnostic copy prints distinct heap-address-like words. A 32-bit standalone
probe passes, while larger compilation contexts can fail there too.

The reduction uses ordinary Word64 arguments, recursion and an end-of-stream
mixed tuple binding. Nonrecursive and simpler recursive controls pass; compiling
the failing function can also affect a control in the same source unit. The
compiler mechanism is not established. No graph input, floating-point arithmetic,
parallel execution or collector stress is needed for the small reproduction.
Source, controls and exact transcripts are retained rather than rewriting the
valid checker to hide the failure.

Rune, MLton, Poly/ML and ML Kit pass the private streaming-checker tests.
A first native build also identified a missing explicit integer annotation in
the source translation. That portable type annotation is corrected; the failed
initial logs remain separate from later numerical/runtime findings.

Every selected measurement requires its own successful primary check.
Failures and unavailable checks remain visible; no checker failure supplies
an accepted timing sample.
