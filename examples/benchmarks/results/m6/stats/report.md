# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| primes-lazy | smoke | rune | O2 | compile | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| primes-lazy | smoke | rune | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-lazy | smoke | rune | O2 | stats | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-lazy | smoke | rune:opt | O2 | compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| primes-lazy | smoke | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| primes-lazy | smoke | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-lazy | smoke | rune:opt | O2 | stats | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-lazy | smoke | rune:new | O2 | compile | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |
| primes-lazy | smoke | rune:new | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-lazy | smoke | rune:new | O2 | stats | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-lazy | smoke | rune:jit | O2 | compile | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |
| primes-lazy | smoke | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| primes-lazy | smoke | rune:jit | O2 | stats | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| primes-strict | smoke | rune | O2 | compile | 1/1 | 1.030000000 | 1.030000000 to 1.030000000 | - |
| primes-strict | smoke | rune | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-strict | smoke | rune | O2 | stats | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-strict | smoke | rune:opt | O2 | compile | 1/1 | 0.990000000 | 0.990000000 to 0.990000000 | - |
| primes-strict | smoke | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| primes-strict | smoke | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-strict | smoke | rune:opt | O2 | stats | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-strict | smoke | rune:new | O2 | compile | 1/1 | 1.030000000 | 1.030000000 to 1.030000000 | - |
| primes-strict | smoke | rune:new | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-strict | smoke | rune:new | O2 | stats | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-strict | smoke | rune:jit | O2 | compile | 1/1 | 0.990000000 | 0.990000000 to 0.990000000 | - |
| primes-strict | smoke | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| primes-strict | smoke | rune:jit | O2 | stats | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |

Failure categories and artifact paths:

