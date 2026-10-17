# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| primetest-lazy | normal | rune | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| primetest-lazy | normal | rune | O2 | correctness | 1/1 | 8.470000000 | 8.470000000 to 8.470000000 | - |
| primetest-lazy | normal | rune | O2 | count | 1/1 | 8.330000000 | 8.330000000 to 8.330000000 | 1997403412/2442803600/61408500 |
| primetest-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.770000000 | 1.770000000 to 1.770000000 | - |
| primetest-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | - |
| primetest-lazy | normal | rune:opt | O2 | correctness | 1/1 | 5.540000000 | 5.540000000 to 5.540000000 | - |
| primetest-lazy | normal | rune:opt | O2 | count | 1/1 | 3.150000000 | 3.150000000 to 3.150000000 | 1997403412/2442803600/61408500 |
| primetest-lazy | normal | rune:new | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| primetest-lazy | normal | rune:new | O2 | correctness | 1/1 | 6.020000000 | 6.020000000 to 6.020000000 | - |
| primetest-lazy | normal | rune:new | O2 | count | 1/1 | 6.250000000 | 6.250000000 to 6.250000000 | 1133702856/2442803600/61408500 |
| primetest-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| primetest-lazy | normal | rune:jit | O2 | correctness | 1/1 | 2.190000000 | 2.190000000 to 2.190000000 | - |
| primetest-lazy | normal | rune:jit | O2 | count | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | 1133702856/2442803600/61408500 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

