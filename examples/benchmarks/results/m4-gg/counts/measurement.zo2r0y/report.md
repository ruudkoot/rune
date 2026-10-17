# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gg-lazy | normal | rune | O2 | compile | 1/1 | 3.190000000 | 3.190000000 to 3.190000000 | - |
| gg-lazy | normal | rune | O2 | correctness | 1/1 | 37.470000000 | 37.470000000 to 37.470000000 | - |
| gg-lazy | normal | rune | O2 | count | 1/1 | 34.980000000 | 34.980000000 to 34.980000000 | 6901170846/15669080480/454752492 |
| gg-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.650000000 | 2.650000000 to 2.650000000 | - |
| gg-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.800000000 | 0.800000000 to 0.800000000 | - |
| gg-lazy | normal | rune:opt | O2 | correctness | 1/1 | 20.660000000 | 20.660000000 to 20.660000000 | - |
| gg-lazy | normal | rune:opt | O2 | count | 1/1 | 18.180000000 | 18.180000000 to 18.180000000 | 6901170846/15669080480/454752492 |
| gg-lazy | normal | rune:new | O2 | compile | 1/1 | 2.840000000 | 2.840000000 to 2.840000000 | - |
| gg-lazy | normal | rune:new | O2 | correctness | 1/1 | 32.760000000 | 32.760000000 to 32.760000000 | - |
| gg-lazy | normal | rune:new | O2 | count | 1/1 | 32.160000000 | 32.160000000 to 32.160000000 | 3977567725/15669080480/454752492 |
| gg-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.600000000 | 2.600000000 to 2.600000000 | - |
| gg-lazy | normal | rune:jit | O2 | correctness | 1/1 | 16.170000000 | 16.170000000 to 16.170000000 | - |
| gg-lazy | normal | rune:jit | O2 | count | 1/1 | 15.750000000 | 15.750000000 to 15.750000000 | 3977567725/15669080480/454752492 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

