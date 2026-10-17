# ALMABENCH host diagnostics

Original and independent ERFA point samples are separate from exact Basis
controls. All six native hosts pass the sampled ephemeris values at the
documented point bounds in the private target.

The exact remainder control reproduces existing SML/NJ arithmetic inexactness:
Real.rem (~7.0, 3.0) gives approximately ~1.0000000000000004 instead of ~1.0
on legacy 64-bit/32-bit SML/NJ 110.99.9 and development SML/NJ 2026.2.
The result still has the expected sign and magnitude. Positive dividends also
show the finite inexactness; do not describe this as a sign-reversal bug.

[The Basis specification](https://smlfamily.github.io/Basis/real.html#SIG:REAL.rem:VAL)
defines the truncated-quotient remainder. The repository already records SML/NJ
Real.rem inexactness in tests/basis/deviations.txt. The new standalone control
prints actual values and separately tests exactness, sign and magnitude.
Keep the valid source and exact control rather than change the workload or
broaden an unrelated numerical tolerance.

The 163-check canonical target retains the auxiliary exact-result failure,
separately from original/ERFA state checks and aggregate profile validation.
Failed primary validation cannot supply an accepted timing result.

Early private attempts exposed two harness mistakes: canonical SML argument
syntax was applied to signed reference dates, and native temporary directories
could not resolve a relative fixture path. Both are corrected in test support,
with the original numeric kernel unchanged. Those development failures do not
identify compiler bugs. Initial format-only probe transcripts lack the standard
summary protocol; the later assertion target supplies ordinary check statuses.

Reference-only ERFA C sources keep their complete notices and pinned identities.
The portable benchmark itself is entirely SML97 and has no C/FFI dependency.
