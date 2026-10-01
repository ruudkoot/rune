# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| primes-lazy | normal | rune | O2 | compile | 1/1 | 1.020000000 | 1.020000000 to 1.020000000 | - |
| primes-lazy | normal | rune | O2 | correctness | 1/1 | 0.680000000 | 0.680000000 to 0.680000000 | - |
| primes-lazy | normal | rune | O2 | repeated | 10/10 | 0.117357500 | 0.114352750 to 0.138893000 | - |
| primes-lazy | normal | native:mlton@20241230 | O2 | compile | 1/1 | 3.850000000 | 3.850000000 to 3.850000000 | - |
| primes-lazy | normal | native:mlton@20241230 | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| primes-lazy | normal | native:mlton@20241230 | O2 | repeated | 10/10 | 0.008902500 | 0.008815750 to 0.009090250 | - |
| primes-lazy | normal | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| primes-lazy | normal | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| primes-lazy | normal | native:smlnj-legacy@110.99.9 | O2 | repeated | 10/10 | 0.029643000 | 0.027679750 to 0.035547750 | - |
| primes-lazy | normal | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| primes-lazy | normal | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| primes-lazy | normal | native:polyml@5.9.2 | O2 | repeated | 10/10 | 0.035723500 | 0.028307500 to 0.039045750 | - |
| primes-strict | normal | rune | O2 | compile | 1/1 | 1.000000000 | 1.000000000 to 1.000000000 | - |
| primes-strict | normal | rune | O2 | correctness | 1/1 | 7.000000000 | 7.000000000 to 7.000000000 | - |
| primes-strict | normal | rune | O2 | repeated | 10/10 | 1.378793500 | 1.363844250 to 1.391715500 | - |
| primes-strict | normal | native:mlton@20241230 | O2 | compile | 1/1 | 4.090000000 | 4.090000000 to 4.090000000 | - |
| primes-strict | normal | native:mlton@20241230 | O2 | correctness | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| primes-strict | normal | native:mlton@20241230 | O2 | repeated | 10/10 | 0.244853500 | 0.236854000 to 0.258057750 | - |
| primes-strict | normal | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| primes-strict | normal | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| primes-strict | normal | native:smlnj-legacy@110.99.9 | O2 | repeated | 10/10 | 0.323051000 | 0.308753000 to 0.324526000 | - |
| primes-strict | normal | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| primes-strict | normal | native:polyml@5.9.2 | O2 | correctness | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | - |
| primes-strict | normal | native:polyml@5.9.2 | O2 | repeated | 10/10 | 0.284275500 | 0.256926000 to 0.297890500 | - |

Failure categories and artifact paths:

