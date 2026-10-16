# Wang host diagnostics, preliminary source review

The default 37-check program passes on Rune's four engines, MLton, Poly/ML and
ML Kit. It fails on the supplied SML/NJ 110.99.9 64-bit and 2026.2 hosts for
strict nonuniform inputs; 32-bit 110.99.9 crashes. Observed first values include
a tiny subnormal or NaN where the original GHC program and independent blocked
model return one. The default replay reproduces these outcomes. Every host
passes all 37 checks with a separate @SMLalloc=64m replay. The kernel is unchanged;
the larger nursery is diagnostic and does not replace default validation.

This is evidence of sensitivity to garbage collection, with the exact cause
still unreduced. The current program uses only portable SML/Basis operations.
The local report docs/bugreport/smlnj/GC/real-corrupted-on-64-bit describes a known
64-bit legacy root-saving bug; its documented scope does not account for every
host here. The reports for spilled numeric arguments and upstream issues 381/394
are additional references, not an established attribution for this application.

Public issue metadata and comments were fetched on 2026-10-16 and saved under
issue-snapshots/. smlnj/smlnj#394 is closed; its resolution describes raw numeric
records and arity-lowering GC invariants, with fixes intended for 2026.3. The
suite's supplied dev host identifies as 2026.2. These observations do not establish
that Wang has the same cause or that current upstream builds still fail.
https://github.com/smlnj/smlnj/issues/394
https://github.com/smlnj/legacy/issues/381

The benchmark will keep the source arithmetic, representation and default host
settings. Failed correctness cannot contribute timing samples. Whole-program
profile checks and this auxiliary nonuniform diagnostic remain distinct. The
standalone full SML kernel/test sources, inputs, raw logs and nursery replay JSON
allow further reduction without changing the benchmark contract.
