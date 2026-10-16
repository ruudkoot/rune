# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| compress-lazy | normal | rune | O2 | compile | 1/1 | 1.690000000 | 1.690000000 to 1.690000000 | - |
| compress-lazy | normal | rune | O2 | correctness | 1/1 | 10.190000000 | 10.190000000 to 10.190000000 | - |
| compress-lazy | normal | rune | O2 | count | 1/1 | 8.820000000 | 8.820000000 to 8.820000000 | 2053384980/6496245408/152467444 |
| compress-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| compress-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| compress-lazy | normal | rune:opt | O2 | correctness | 1/1 | 5.570000000 | 5.570000000 to 5.570000000 | - |
| compress-lazy | normal | rune:opt | O2 | count | 1/1 | 4.470000000 | 4.470000000 to 4.470000000 | 2053384980/6496245408/152467444 |
| compress-lazy | normal | rune:new | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| compress-lazy | normal | rune:new | O2 | correctness | 1/1 | 8.200000000 | 8.200000000 to 8.200000000 | - |
| compress-lazy | normal | rune:new | O2 | count | 1/1 | 8.140000000 | 8.140000000 to 8.140000000 | 1164037048/6496245408/152467444 |
| compress-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| compress-lazy | normal | rune:jit | O2 | correctness | 1/1 | 5.260000000 | 5.260000000 to 5.260000000 | - |
| compress-lazy | normal | rune:jit | O2 | count | 1/1 | 4.070000000 | 4.070000000 to 4.070000000 | 1164037048/6496245408/152467444 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

