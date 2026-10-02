# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| primes-lazy | smoke | rune | O2 | compile | 1/1 | 0.980000000 | 0.980000000 to 0.980000000 | - |
| primes-lazy | smoke | rune | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-lazy | smoke | rune | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 15010/35232/976 |
| primes-lazy | smoke | rune:opt | O2 | compile | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| primes-lazy | smoke | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| primes-lazy | smoke | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-lazy | smoke | rune:opt | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 15010/35232/976 |
| primes-lazy | smoke | rune:new | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| primes-lazy | smoke | rune:new | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-lazy | smoke | rune:new | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 9064/35232/976 |
| primes-lazy | smoke | rune:jit | O2 | compile | 1/1 | 0.980000000 | 0.980000000 to 0.980000000 | - |
| primes-lazy | smoke | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| primes-lazy | smoke | rune:jit | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 9064/35232/976 |
| primes-strict | smoke | rune | O2 | compile | 1/1 | 0.980000000 | 0.980000000 to 0.980000000 | - |
| primes-strict | smoke | rune | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-strict | smoke | rune | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 19903/33440/862 |
| primes-strict | smoke | rune:opt | O2 | compile | 1/1 | 1.020000000 | 1.020000000 to 1.020000000 | - |
| primes-strict | smoke | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| primes-strict | smoke | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-strict | smoke | rune:opt | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 19903/33440/862 |
| primes-strict | smoke | rune:new | O2 | compile | 1/1 | 1.050000000 | 1.050000000 to 1.050000000 | - |
| primes-strict | smoke | rune:new | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| primes-strict | smoke | rune:new | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 12008/33440/862 |
| primes-strict | smoke | rune:jit | O2 | compile | 1/1 | 0.970000000 | 0.970000000 to 0.970000000 | - |
| primes-strict | smoke | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| primes-strict | smoke | rune:jit | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 12008/33440/862 |
|  | smoke | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

