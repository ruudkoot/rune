# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lcss-nofib-lazy | normal | rune | O2 | compile | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| lcss-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 2.620000000 | 2.620000000 to 2.620000000 | - |
| lcss-nofib-lazy | normal | rune | O2 | count | 1/1 | 2.960000000 | 2.960000000 to 2.960000000 | 686377010/2447317432/65378555 |
| lcss-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| lcss-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| lcss-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| lcss-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | 686377010/2447317432/65378555 |
| lcss-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| lcss-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 2.570000000 | 2.570000000 to 2.570000000 | - |
| lcss-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 2.630000000 | 2.630000000 to 2.630000000 | 385387718/2447317432/65378555 |
| lcss-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| lcss-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| lcss-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | 385387718/2447317432/65378555 |
| lcss-nofib-strict | normal | rune | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| lcss-nofib-strict | normal | rune | O2 | correctness | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | - |
| lcss-nofib-strict | normal | rune | O2 | count | 1/1 | 0.610000000 | 0.610000000 to 0.610000000 | 181007026/387737312/9702046 |
| lcss-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| lcss-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| lcss-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| lcss-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 181007026/387737312/9702046 |
| lcss-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| lcss-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 0.470000000 | 0.470000000 to 0.470000000 | - |
| lcss-nofib-strict | normal | rune:new | O2 | count | 1/1 | 0.520000000 | 0.520000000 to 0.520000000 | 76880724/387737312/9702046 |
| lcss-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| lcss-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| lcss-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 76880724/387737312/9702046 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

