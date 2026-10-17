# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| knights-array-lazy | normal | rune | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| knights-array-lazy | normal | rune | O2 | correctness | 1/1 | 11.260000000 | 11.260000000 to 11.260000000 | - |
| knights-array-lazy | normal | rune | O2 | count | 1/1 | 13.250000000 | 13.250000000 to 13.250000000 | 2090039054/4671853232/100310696 |
| knights-array-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.580000000 | 1.580000000 to 1.580000000 | - |
| knights-array-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| knights-array-lazy | normal | rune:opt | O2 | correctness | 1/1 | 4.790000000 | 4.790000000 to 4.790000000 | - |
| knights-array-lazy | normal | rune:opt | O2 | count | 1/1 | 5.080000000 | 5.080000000 to 5.080000000 | 2090039054/4671853232/100310696 |
| knights-array-lazy | normal | rune:new | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| knights-array-lazy | normal | rune:new | O2 | correctness | 1/1 | 10.020000000 | 10.020000000 to 10.020000000 | - |
| knights-array-lazy | normal | rune:new | O2 | count | 1/1 | 11.650000000 | 11.650000000 to 11.650000000 | 1310869700/4671853232/100310696 |
| knights-array-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.160000000 | 2.160000000 to 2.160000000 | - |
| knights-array-lazy | normal | rune:jit | O2 | correctness | 1/1 | 5.420000000 | 5.420000000 to 5.420000000 | - |
| knights-array-lazy | normal | rune:jit | O2 | count | 1/1 | 4.880000000 | 4.880000000 to 4.880000000 | 1310869700/4671853232/100310696 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

