# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| life-nofib-lazy | normal | rune | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| life-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| life-nofib-lazy | normal | rune | O2 | count | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | 343432674/934501224/26761913 |
| life-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| life-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| life-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | - |
| life-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 0.830000000 | 0.830000000 to 0.830000000 | 343432674/934501224/26761913 |
| life-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 2.330000000 | 2.330000000 to 2.330000000 | - |
| life-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| life-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | 192087803/934501224/26761913 |
| life-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| life-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| life-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | 192087803/934501224/26761913 |
| life-nofib-strict | normal | rune | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| life-nofib-strict | normal | rune | O2 | correctness | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| life-nofib-strict | normal | rune | O2 | count | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | 102968452/208993248/4805410 |
| life-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| life-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| life-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| life-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 102968452/208993248/4805410 |
| life-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| life-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| life-nofib-strict | normal | rune:new | O2 | count | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | 46332821/208993248/4805410 |
| life-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| life-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| life-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 46332821/208993248/4805410 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

