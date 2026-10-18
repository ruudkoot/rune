# LexiFi G2++ validation

Canonical coverage records 24 of 28 passing smoke/normal cases. Every Rune
O0/O2 engine, MLton, SML/NJ 2026.2, Poly/ML and ML Kit passes. Both profiles
fail on native 32-bit SML/NJ's known bounded-random Overflow and on the default
legacy 64-bit runtime. Incorrect/runtime failures remain in coverage.tsv.

The final 67-assertion target completes on all twenty invocations: 1326 pass,
14 fail, none unreached. Native 32-bit has six failures per invocation; legacy
64-bit has one failed calibration per invocation. Uniform numerical bounds
pass the other configurations. Checker rejection controls use independent
original oracle data, so a failed host calculation cannot invalidate their
positive/negative baseline.

All five parameters, RMS and all 196 calibrated/market price pairs are checked.
Original full-precision observers, independently recomputed RMS, calendar/
erf/square-root observations and exact source optimizer traces support the port.
Source seed/draw order, array scopes, root rules and strict evaluation-budget
comparison remain. The original normal budget is retained.

Four normal Rune count samples agree with a zero-exit, uninterrupted guard.
Two serial single fresh-process native smoke diagnostics pass. The legacy
correctness phase fails before timing; no fresh sample is accepted for it.
These diagnostics are not ten-sample comparative performance claims.

Five default legacy calibration diagnostics fail and five 64 MiB nursery
diagnostics pass; suite defaults remain unchanged. This is consistent with the
existing real/GC report, without proving its cause for this application.
Small stable Math.exp differences are separate from the large failures.
The initial market-only bound was tighter than the calibrated-price bound;
the final common bound and perturbation controls are documented in provenance.

Raw canonical and semantic outputs, notices, source/input identities, original
observers and development scopes are retained. Initial strict numerical probes,
a diagnostic without SUMMARY and a shell-target/setup error are development
evidence, not final passes. Public Rune O0/O2 semantic targets and the 114-test
inventory/five-pin checks pass. Full final SML large runs remain unrecorded.
The full repository acceptance run exits zero with 1325 profiles and all
compiler/runedoc/runeopt cross-build comparisons.
