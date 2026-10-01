# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| primes-lazy | normal | rune | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| primes-lazy | normal | rune | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| primes-lazy | normal | rune | O2 | fresh | 10/10 | 0.135000000 | 0.122500000 to 0.140000000 | - |
| primes-lazy | normal | native:mlton@20241230 | O2 | compile | 1/1 | 3.760000000 | 3.760000000 to 3.760000000 | - |
| primes-lazy | normal | native:mlton@20241230 | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| primes-lazy | normal | native:mlton@20241230 | O2 | fresh | 10/10 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| primes-lazy | normal | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| primes-lazy | normal | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| primes-lazy | normal | native:smlnj-legacy@110.99.9 | O2 | fresh | 10/10 | 0.050000000 | 0.050000000 to 0.057500000 | - |
| primes-lazy | normal | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| primes-lazy | normal | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| primes-lazy | normal | native:polyml@5.9.2 | O2 | fresh | 10/10 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| primes-strict | normal | rune | O2 | compile | 1/1 | 1.010000000 | 1.010000000 to 1.010000000 | - |
| primes-strict | normal | rune | O2 | correctness | 1/1 | 1.380000000 | 1.380000000 to 1.380000000 | - |
| primes-strict | normal | rune | O2 | fresh | 10/10 | 1.400000000 | 1.380000000 to 1.410000000 | - |
| primes-strict | normal | native:mlton@20241230 | O2 | compile | 1/1 | 3.800000000 | 3.800000000 to 3.800000000 | - |
| primes-strict | normal | native:mlton@20241230 | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| primes-strict | normal | native:mlton@20241230 | O2 | fresh | 10/10 | 0.250000000 | 0.240000000 to 0.260000000 | - |
| primes-strict | normal | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| primes-strict | normal | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| primes-strict | normal | native:smlnj-legacy@110.99.9 | O2 | fresh | 10/10 | 0.340000000 | 0.330000000 to 0.340000000 | - |
| primes-strict | normal | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| primes-strict | normal | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| primes-strict | normal | native:polyml@5.9.2 | O2 | fresh | 10/10 | 0.255000000 | 0.250000000 to 0.267500000 | - |

Failure categories and artifact paths:

