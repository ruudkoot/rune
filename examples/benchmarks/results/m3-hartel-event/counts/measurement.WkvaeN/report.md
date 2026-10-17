# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| event-lazy | normal | rune | O2 | compile | 1/1 | 1.850000000 | 1.850000000 to 1.850000000 | - |
| event-lazy | normal | rune | O2 | correctness | 1/1 | 47.090000000 | 47.090000000 to 47.090000000 | - |
| event-lazy | normal | rune | O2 | count | 1/1 | 40.810000000 | 40.810000000 to 40.810000000 | 7098694044/17103309768/513891007 |
| event-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.020000000 | 2.020000000 to 2.020000000 | - |
| event-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| event-lazy | normal | rune:opt | O2 | correctness | 1/1 | 23.520000000 | 23.520000000 to 23.520000000 | - |
| event-lazy | normal | rune:opt | O2 | count | 1/1 | 21.580000000 | 21.580000000 to 21.580000000 | 7098694044/17103309768/513891007 |
| event-lazy | normal | rune:new | O2 | compile | 1/1 | 1.820000000 | 1.820000000 to 1.820000000 | - |
| event-lazy | normal | rune:new | O2 | correctness | 1/1 | 39.810000000 | 39.810000000 to 39.810000000 | - |
| event-lazy | normal | rune:new | O2 | count | 1/1 | 47.470000000 | 47.470000000 to 47.470000000 | 4205167376/17103309768/513891007 |
| event-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| event-lazy | normal | rune:jit | O2 | correctness | 1/1 | 23.760000000 | 23.760000000 to 23.760000000 | - |
| event-lazy | normal | rune:jit | O2 | count | 1/1 | 20.830000000 | 20.830000000 to 20.830000000 | 4205167376/17103309768/513891007 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

