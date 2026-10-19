# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fluid-lazy | normal | rune | O2 | compile | 1/1 | 6.420000000 | 6.420000000 to 6.420000000 | - |
| fluid-lazy | normal | rune | O2 | correctness | 1/1 | 38.090000000 | 38.090000000 to 38.090000000 | - |
| fluid-lazy | normal | rune | O2 | count | 1/1 | 35.930000000 | 35.930000000 to 35.930000000 | 4338361785/11860507272/364010059 |
| fluid-lazy | normal | rune:opt | O2 | compile | 1/1 | 7.000000000 | 7.000000000 to 7.000000000 | - |
| fluid-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| fluid-lazy | normal | rune:opt | O2 | correctness | 1/1 | 17.470000000 | 17.470000000 to 17.470000000 | - |
| fluid-lazy | normal | rune:opt | O2 | count | 1/1 | 19.710000000 | 19.710000000 to 19.710000000 | 4338361785/11860507272/364010059 |
| fluid-lazy | normal | rune:new | O2 | compile | 1/1 | 5.530000000 | 5.530000000 to 5.530000000 | - |
| fluid-lazy | normal | rune:new | O2 | correctness | 1/1 | 41.150000000 | 41.150000000 to 41.150000000 | - |
| fluid-lazy | normal | rune:new | O2 | count | 1/1 | 45.000000000 | 45.000000000 to 45.000000000 | 2562082295/11860507272/364010059 |
| fluid-lazy | normal | rune:jit | O2 | compile | 1/1 | 8.070000000 | 8.070000000 to 8.070000000 | - |
| fluid-lazy | normal | rune:jit | O2 | correctness | 1/1 | 14.520000000 | 14.520000000 to 14.520000000 | - |
| fluid-lazy | normal | rune:jit | O2 | count | 1/1 | 16.900000000 | 16.900000000 to 16.900000000 | 2562082295/11860507272/364010059 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

