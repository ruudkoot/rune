# G2++ native-host observations

The unchanged kernel passes its original full 2000-budget calibration on Rune.
Original references retain all five parameters, RMS and 196 price pairs.
The original source's counter limit is strict: a full population is evaluated
before the comparison maxf < ncalls.

The 32-bit SML/NJ random rejection guard reproduces the existing
examples/benchmarks/validation/smlnj32-random.md Overflow. All twenty raw
30-bit draws and their direct mod-40 results complete; the bounded draw fails.
No alternative expression or seed is substituted.

All three SML/NJ hosts return approximately 0.6065306597235144 for
Math.exp(~u*u), u=1/sqrt(2), where the original OCaml and four comparison
implementations return approximately 0.60653065971263354. This produces an
approximately 2.85e-12 CDF difference at 1. The Basis MATH description permits
approximation algorithms and does not specify a uniform ulp budget:
https://smlfamily.github.io/Basis/math.html . This observation is not claimed
as a proved language-conformance bug.

The first pilot used an unnecessarily tighter bound for market prices than
for calibrated prices. The final check uses the same 1e-9 absolute plus 1e-8
relative bound for both price arrays, much narrower than the source's printed
price resolution (0.01/10000). CDF support observations use 1e-10 absolute plus
relative tolerance; exact date/integer/counter observations remain exact.
The preliminary strict records remain development evidence. Independent
perturbations at twice the final bound must fail on each side; one tenth
of the bound must pass. The checker tests use original oracle data independently
of a possibly failing host calculation.

A default-setting legacy 64-bit diagnostic returned maximum absolute price
error 0.11171587557540603 and RMS 26.082916405832208 for the 40-budget run,
despite retaining the original parameters. Other original semantic runs aborted
while evaluating that calibration. This is distinct from the much smaller,
stable Math.exp accuracy difference. Existing docs/bugreport/smlnj/GC/
real-corrupted-on-64-bit/BUGREPORT.md is relevant; the application is not
itself a reduction proving that GC cause. Preserve default-setting failures.
A separate 2026.2 diagnostic differs by at most approximately 1.73e-11 in
calibrated prices and 5.47e-11 in market prices, within the final shared bound.

The first diagnostic used the matrix runner without a SUMMARY, so that runner
reported failures even for zero-exit observational processes. Its stdout is
raw diagnostic evidence, not a semantic pass ledger. Later checked diagnostics
record actual assertions and exceptions.
