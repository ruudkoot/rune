# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| parser-lazy | normal | rune | O2 | compile | 1/1 | 3.480000000 | 3.480000000 to 3.480000000 | - |
| parser-lazy | normal | rune | O2 | correctness | 1/1 | 74.790000000 | 74.790000000 to 74.790000000 | - |
| parser-lazy | normal | rune | O2 | count | 1/1 | 82.720000000 | 82.720000000 to 82.720000000 | 9943487516/27556604768/771275764 |
| parser-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.790000000 | 3.790000000 to 3.790000000 | - |
| parser-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.060000000 | 1.060000000 to 1.060000000 | - |
| parser-lazy | normal | rune:opt | O2 | correctness | 1/1 | 39.630000000 | 39.630000000 to 39.630000000 | - |
| parser-lazy | normal | rune:opt | O2 | count | 1/1 | 38.220000000 | 38.220000000 to 38.220000000 | 9943487516/27556604768/771275764 |
| parser-lazy | normal | rune:new | O2 | compile | 1/1 | 3.840000000 | 3.840000000 to 3.840000000 | - |
| parser-lazy | normal | rune:new | O2 | correctness | 1/1 | 67.250000000 | 67.250000000 to 67.250000000 | - |
| parser-lazy | normal | rune:new | O2 | count | 1/1 | 71.530000000 | 71.530000000 to 71.530000000 | 5970451204/27556604768/771275764 |
| parser-lazy | normal | rune:jit | O2 | compile | 1/1 | 6.150000000 | 6.150000000 to 6.150000000 | - |
| parser-lazy | normal | rune:jit | O2 | correctness | 1/1 | 38.950000000 | 38.950000000 to 38.950000000 | - |
| parser-lazy | normal | rune:jit | O2 | count | 1/1 | 37.090000000 | 37.090000000 to 37.090000000 | 5970451204/27556604768/771275764 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

