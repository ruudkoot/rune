# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| pidigits-nofib-lazy | normal | rune | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| pidigits-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 23.650000000 | 23.650000000 to 23.650000000 | - |
| pidigits-nofib-lazy | normal | rune | O2 | count | 1/1 | 26.040000000 | 26.040000000 to 26.040000000 | 6079845975/6406446680/160168065 |
| pidigits-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| pidigits-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| pidigits-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 11.290000000 | 11.290000000 to 11.290000000 | - |
| pidigits-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 11.030000000 | 11.030000000 to 11.030000000 | 6079845975/6406446680/160168065 |
| pidigits-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| pidigits-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 18.820000000 | 18.820000000 to 18.820000000 | - |
| pidigits-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 19.080000000 | 19.080000000 to 19.080000000 | 3415443465/6406446680/160168065 |
| pidigits-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| pidigits-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 8.900000000 | 8.900000000 to 8.900000000 | - |
| pidigits-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 8.800000000 | 8.800000000 to 8.800000000 | 3415443465/6406446680/160168065 |
| pidigits-nofib-strict | normal | rune | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| pidigits-nofib-strict | normal | rune | O2 | correctness | 1/1 | 24.220000000 | 24.220000000 to 24.220000000 | - |
| pidigits-nofib-strict | normal | rune | O2 | count | 1/1 | 23.940000000 | 23.940000000 to 23.940000000 | 6079725681/6406014712/160155205 |
| pidigits-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| pidigits-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| pidigits-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 11.730000000 | 11.730000000 to 11.730000000 | - |
| pidigits-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 11.340000000 | 11.340000000 to 11.340000000 | 6079725681/6406014712/160155205 |
| pidigits-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| pidigits-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 19.640000000 | 19.640000000 to 19.640000000 | - |
| pidigits-nofib-strict | normal | rune:new | O2 | count | 1/1 | 19.790000000 | 19.790000000 to 19.790000000 | 3415368099/6406014712/160155205 |
| pidigits-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| pidigits-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 9.510000000 | 9.510000000 to 9.510000000 | - |
| pidigits-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 8.710000000 | 8.710000000 to 8.710000000 | 3415368099/6406014712/160155205 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

