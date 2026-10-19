# fft2-lazy provenance

Numeric policy: lazy.

### Algorithm and workload

Compute fast FFT/inverse distance, general mixed-factor DFT/inverse distance
and the sum of a slow cosine transform over independent ramps. Retain list
algorithms, cyclic roots, the factor sieve, transpose/zip structure, numeric
operation order and separate signal generation for the three measurements.
No result cache or replacement transform is used in the benchmark.

### History, authorship and variants

Rex Page, Amoco Production Research, September 1992. Pinned nofib revision
b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/fft2. Retain fft2 as distinct
from classic FFT, spectral/hartel/fft and Sandmark FFT, with explicit lazy/strict
suffixes. Complete original modules, MAIL, README.nofib, old platform fixtures
and foreign-language references are retained under fft2-lazy/upstream.

Individual files state no separate redistribution grant; retain all attribution
and do not infer a license from another benchmark. The supplementary inventory
records Rex Page's Miranda and fixed-array Fortran programs as distinct
historical references outside the initial executable language-family set.
Matt Donadio's iterative bit-reversal C FFT is a library fragment without a
standalone workload. No foreign reference is called an exact duplicate.
There are no external datasets; ramp inputs are generated deterministically.
Old platform-specific numeric fixtures remain historical evidence.

### Portable translation and evaluation

All computation and checking uses SML97. Complex coordinates use real arithmetic,
with memoized numeric delays in lazy and eager finite payloads in strict.
Both preserve memoized control streams, shared even-root subsequences, periodic
cyclic lists, the global prime stream and separately delayed transform metrics.
Unused complex coordinates remain demand-sensitive in the lazy policy.

Magnitude/division retain the installed GHC base-4.17.2.0 Data.Complex exponent
scaling and zero-exponent behavior, inspected in its installed interface.
Extreme-value references include the underflow of a tiny coordinate paired with
zero. Integer indices and factors fit portable int in the bounded profile domain.
Floating enumeration retains Haskell's half-step endpoint convention.

For i from one through 100, the source generates base+i/15 and consequently
eight different lengths. Compute each iteration anew. The fast transform assumes
powers of two but source profiles include other lengths: preserve and check its
large nonzero errors instead of silently correcting the source algorithm.

Retain the demand for the length of the quoted result string. GEN17 replaces
shortest decimal spelling; parsed values, escape roundtrips and an independently
computed escaped length validate the consumer. Stable samples:checked output
replaces empty stdout. No hash replaces the formatted-result consumer.

### Profiles and result checks

| Profile | Samples | Base |
|---|---:|---:|
| Smoke | 1 | 70 |
| Normal | 100 | 245 |
| Large | 100 | 490 |

Normal and large retain source counts; smoke reduces FAST's 100 to one.
Original GHC runs match the empty stdout fixture for all full profiles; print
mode supplies all 300 numeric values per profile. An independent eager Python
model agrees on all 300 triples, including non-power-of-two fast-transform errors.
Its reference-only caching of repeated sizes is absent from the SML workload.

For actual length n, fast-transform distance allows absolute 1e-9 plus relative
1e-10. The general-transform residual allows absolute 128*epsilon*n^2*sqrt(n);
the cosine sum allows 128*epsilon*n^3, with binary64 machine epsilon.
These are conservative source-agreement budgets, not a formal proof for all math
libraries. Reject nonfinite values, malformed triples and deliberate perturbations
of each metric; also test an accepted interior point near the bound.
Auxiliary transform vectors use absolute and relative 1e-11.

The semantic target checks all five complex transforms and cosine vectors at
lengths 2,3,4,5,8,16, magnitudes, cyclic lists, factors, floating enumeration,
quoted output, coordinate demand and sharing. Both full normal SML profiles
pass calibration. Full large SML repetition checks remain unrecorded, separately
from validated large fixtures and first-sample checks.

Private Rune, MLton, Poly/ML and ML Kit runs pass 132 checks. Private SML/NJ
runs terminate with bus/segmentation faults or a fatal bogus-overflow diagnostic.
Retain valid source and canonical host settings; the compiler mechanism is
unresolved. Failed correctness checks cannot supply accepted timing samples.
Canonical primary, count and semantic results are recorded as they finish.

### Literature and diagnostic questions

[Cooley and Tukey (1965)](https://doi.org/10.1090/S0025-5718-1965-0178586-1)
provides FFT context; this source's Fourier.lhs and Complex_Vectors.lhs define
the actual algorithms and MAIL records numerical investigations.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies suite
context. Investigate higher-order streams, periodic sharing, complex-coordinate
demand, numeric operation order, transform assumptions and formatting cost.
These are source-based hypotheses until supported by measurements.
