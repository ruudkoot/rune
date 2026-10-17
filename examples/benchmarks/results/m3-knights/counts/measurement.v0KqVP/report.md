# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| knights-lazy | normal | rune | O2 | compile | 1/1 | 1.720000000 | 1.720000000 to 1.720000000 | - |
| knights-lazy | normal | rune | O2 | correctness | 1/1 | 22.530000000 | 22.530000000 to 22.530000000 | - |
| knights-lazy | normal | rune | O2 | count | 1/1 | 23.640000000 | 23.640000000 to 23.640000000 | 3987997860/3661462688/118030898 |
| knights-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.850000000 | 1.850000000 to 1.850000000 | - |
| knights-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| knights-lazy | normal | rune:opt | O2 | correctness | 1/1 | 11.060000000 | 11.060000000 to 11.060000000 | - |
| knights-lazy | normal | rune:opt | O2 | count | 1/1 | 10.510000000 | 10.510000000 to 10.510000000 | 3987997860/3661462688/118030898 |
| knights-lazy | normal | rune:new | O2 | compile | 1/1 | 2.600000000 | 2.600000000 to 2.600000000 | - |
| knights-lazy | normal | rune:new | O2 | correctness | 1/1 | 25.770000000 | 25.770000000 to 25.770000000 | - |
| knights-lazy | normal | rune:new | O2 | count | 1/1 | 22.530000000 | 22.530000000 to 22.530000000 | 2271850636/3661462688/118030898 |
| knights-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| knights-lazy | normal | rune:jit | O2 | correctness | 1/1 | 8.610000000 | 8.610000000 to 8.610000000 | - |
| knights-lazy | normal | rune:jit | O2 | count | 1/1 | 8.820000000 | 8.820000000 to 8.820000000 | 2271850636/3661462688/118030898 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

