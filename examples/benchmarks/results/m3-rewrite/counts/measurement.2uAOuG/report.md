# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| rewrite-lazy | normal | rune | O2 | compile | 1/1 | 3.100000000 | 3.100000000 to 3.100000000 | - |
| rewrite-lazy | normal | rune | O2 | correctness | 1/1 | 70.300000000 | 70.300000000 to 70.300000000 | - |
| rewrite-lazy | normal | rune | O2 | count | 1/1 | 58.360000000 | 58.360000000 to 58.360000000 | 5595565633/16532153864/485683525 |
| rewrite-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.110000000 | 2.110000000 to 2.110000000 | - |
| rewrite-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.510000000 | 0.510000000 to 0.510000000 | - |
| rewrite-lazy | normal | rune:opt | O2 | correctness | 1/1 | 17.010000000 | 17.010000000 to 17.010000000 | - |
| rewrite-lazy | normal | rune:opt | O2 | count | 1/1 | 15.250000000 | 15.250000000 to 15.250000000 | 5595565633/16532153864/485683525 |
| rewrite-lazy | normal | rune:new | O2 | compile | 1/1 | 3.990000000 | 3.990000000 to 3.990000000 | - |
| rewrite-lazy | normal | rune:new | O2 | correctness | 1/1 | 59.090000000 | 59.090000000 to 59.090000000 | - |
| rewrite-lazy | normal | rune:new | O2 | count | 1/1 | 54.610000000 | 54.610000000 to 54.610000000 | 3259268506/16532153864/485683525 |
| rewrite-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| rewrite-lazy | normal | rune:jit | O2 | correctness | 1/1 | 23.400000000 | 23.400000000 to 23.400000000 | - |
| rewrite-lazy | normal | rune:jit | O2 | count | 1/1 | 21.250000000 | 21.250000000 to 21.250000000 | 3259268506/16532153864/485683525 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

