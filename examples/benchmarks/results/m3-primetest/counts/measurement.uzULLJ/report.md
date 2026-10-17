# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| primetest-strict | normal | rune | O2 | compile | 1/1 | 1.580000000 | 1.580000000 to 1.580000000 | - |
| primetest-strict | normal | rune | O2 | correctness | 1/1 | 9.920000000 | 9.920000000 to 9.920000000 | - |
| primetest-strict | normal | rune | O2 | count | 1/1 | 7.270000000 | 7.270000000 to 7.270000000 | 1999899601/2444960960/61451730 |
| primetest-strict | normal | rune:opt | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| primetest-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| primetest-strict | normal | rune:opt | O2 | correctness | 1/1 | 2.890000000 | 2.890000000 to 2.890000000 | - |
| primetest-strict | normal | rune:opt | O2 | count | 1/1 | 2.910000000 | 2.910000000 to 2.910000000 | 1999899601/2444960960/61451730 |
| primetest-strict | normal | rune:new | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| primetest-strict | normal | rune:new | O2 | correctness | 1/1 | 6.170000000 | 6.170000000 to 6.170000000 | - |
| primetest-strict | normal | rune:new | O2 | count | 1/1 | 6.470000000 | 6.470000000 to 6.470000000 | 1135103755/2444960960/61451730 |
| primetest-strict | normal | rune:jit | O2 | compile | 1/1 | 3.760000000 | 3.760000000 to 3.760000000 | - |
| primetest-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | - |
| primetest-strict | normal | rune:jit | O2 | count | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | 1135103755/2444960960/61451730 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

