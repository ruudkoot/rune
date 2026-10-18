# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| transform-lazy | normal | rune | O2 | compile | 1/1 | 5.820000000 | 5.820000000 to 5.820000000 | - |
| transform-lazy | normal | rune | O2 | correctness | 1/1 | 81.180000000 | 81.180000000 to 81.180000000 | - |
| transform-lazy | normal | rune | O2 | count | 1/1 | 76.270000000 | 76.270000000 to 76.270000000 | 6558673533/17112233616/521521734 |
| transform-lazy | normal | rune:opt | O2 | compile | 1/1 | 6.510000000 | 6.510000000 to 6.510000000 | - |
| transform-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 2.540000000 | 2.540000000 to 2.540000000 | - |
| transform-lazy | normal | rune:opt | O2 | correctness | 1/1 | 45.380000000 | 45.380000000 to 45.380000000 | - |
| transform-lazy | normal | rune:opt | O2 | count | 1/1 | 39.190000000 | 39.190000000 to 39.190000000 | 6558673533/17112233616/521521734 |
| transform-lazy | normal | rune:new | O2 | compile | 1/1 | 4.810000000 | 4.810000000 to 4.810000000 | - |
| transform-lazy | normal | rune:new | O2 | correctness | 1/1 | 70.620000000 | 70.620000000 to 70.620000000 | - |
| transform-lazy | normal | rune:new | O2 | count | 1/1 | 67.210000000 | 67.210000000 to 67.210000000 | 3844958876/17112233616/521521734 |
| transform-lazy | normal | rune:jit | O2 | compile | 1/1 | 6.200000000 | 6.200000000 to 6.200000000 | - |
| transform-lazy | normal | rune:jit | O2 | correctness | 1/1 | 29.420000000 | 29.420000000 to 29.420000000 | - |
| transform-lazy | normal | rune:jit | O2 | count | 1/1 | 26.030000000 | 26.030000000 to 26.030000000 | 3844958876/17112233616/521521734 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

