# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gg-pool-lazy | normal | rune | O2 | compile | 1/1 | 2.830000000 | 2.830000000 to 2.830000000 | - |
| gg-pool-lazy | normal | rune | O2 | correctness | 1/1 | 36.270000000 | 36.270000000 to 36.270000000 | - |
| gg-pool-lazy | normal | rune | O2 | count | 1/1 | 35.930000000 | 35.930000000 to 35.930000000 | 6628051852/14482885184/419861688 |
| gg-pool-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.080000000 | 3.080000000 to 3.080000000 | - |
| gg-pool-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.730000000 | 0.730000000 to 0.730000000 | - |
| gg-pool-lazy | normal | rune:opt | O2 | correctness | 1/1 | 18.110000000 | 18.110000000 to 18.110000000 | - |
| gg-pool-lazy | normal | rune:opt | O2 | count | 1/1 | 16.310000000 | 16.310000000 to 16.310000000 | 6628051852/14482885184/419861688 |
| gg-pool-lazy | normal | rune:new | O2 | compile | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | - |
| gg-pool-lazy | normal | rune:new | O2 | correctness | 1/1 | 33.580000000 | 33.580000000 to 33.580000000 | - |
| gg-pool-lazy | normal | rune:new | O2 | count | 1/1 | 31.780000000 | 31.780000000 to 31.780000000 | 3817614689/14482885184/419861688 |
| gg-pool-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.500000000 | 2.500000000 to 2.500000000 | - |
| gg-pool-lazy | normal | rune:jit | O2 | correctness | 1/1 | 14.530000000 | 14.530000000 to 14.530000000 | - |
| gg-pool-lazy | normal | rune:jit | O2 | count | 1/1 | 13.170000000 | 13.170000000 to 13.170000000 | 3817614689/14482885184/419861688 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

