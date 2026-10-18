# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| happy-lazy | normal | rune | O2 | compile | 1/1 | 7.530000000 | 7.530000000 to 7.530000000 | - |
| happy-lazy | normal | rune | O2 | correctness | 1/1 | 88.710000000 | 88.710000000 to 88.710000000 | - |
| happy-lazy | normal | rune | O2 | count | 1/1 | 75.000000000 | 75.000000000 to 75.000000000 | 8486609205/13737228992/386195916 |
| happy-lazy | normal | rune:opt | O2 | compile | 1/1 | 8.200000000 | 8.200000000 to 8.200000000 | - |
| happy-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 3.770000000 | 3.770000000 to 3.770000000 | - |
| happy-lazy | normal | rune:opt | O2 | correctness | 1/1 | 28.990000000 | 28.990000000 to 28.990000000 | - |
| happy-lazy | normal | rune:opt | O2 | count | 1/1 | 36.650000000 | 36.650000000 to 36.650000000 | 8486609205/13737228992/386195916 |
| happy-lazy | normal | rune:new | O2 | compile | 1/1 | 9.130000000 | 9.130000000 to 9.130000000 | - |
| happy-lazy | normal | rune:new | O2 | correctness | 1/1 | 54.580000000 | 54.580000000 to 54.580000000 | - |
| happy-lazy | normal | rune:new | O2 | count | 1/1 | 56.120000000 | 56.120000000 to 56.120000000 | 4804723176/13737228992/386195916 |
| happy-lazy | normal | rune:jit | O2 | compile | 1/1 | 7.450000000 | 7.450000000 to 7.450000000 | - |
| happy-lazy | normal | rune:jit | O2 | correctness | 1/1 | 30.280000000 | 30.280000000 to 30.280000000 | - |
| happy-lazy | normal | rune:jit | O2 | count | 1/1 | 29.510000000 | 29.510000000 to 29.510000000 | 4804723176/13737228992/386195916 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

