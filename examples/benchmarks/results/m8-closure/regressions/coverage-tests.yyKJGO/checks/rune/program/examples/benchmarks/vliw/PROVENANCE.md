# vliw provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/vliw.sml`. Original, adaptation patch and notices retained.

SML/NJ VLIW instruction scheduling/compression workload. Retains ndotprod.s,
instruction parsing, dependency graph, delay handling, compression and output
formats. Reset name allocation and idempotency as the original driver does.
Normal preserves window size 9; smoke selects 3; large repeats window 9 ten times. Consume and
check every instruction token in both assembly outputs. Fixed relative
filenames remove directory identities from output; generated artifacts are
reference fixtures from the pinned original program on MLton.

The initial window-20 large trial raises FILTERSUCC in the upstream code.
That trial is recorded as a failure; it does not define a golden result.
The selected large profile repeats the validated original window-9 workload,
regenerating and validating both outputs on every call.

Real.toString formats integral real literals as 3 on MLton and 3.0 on
Poly/ML. The checker preserves the output and compares GETREAL values by
finite binary64 value and sign, normalizing their mantissa/exponent only for
the digest. Every other instruction token and line remains exact.
