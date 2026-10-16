# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| scs-lazy | normal | rune | O2 | compile | 1/1 | 3.210000000 | 3.210000000 to 3.210000000 | - |
| scs-lazy | normal | rune | O2 | correctness | 1/1 | 111.850000000 | 111.850000000 to 111.850000000 | - |
| scs-lazy | normal | rune | O2 | count | 1/1 | 104.780000000 | 104.780000000 to 104.780000000 | 24079670053/37072526520/1004260753 |
| scs-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.470000000 | 2.470000000 to 2.470000000 | - |
| scs-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | - |
| scs-lazy | normal | rune:opt | O2 | correctness | 1/1 | 45.210000000 | 45.210000000 to 45.210000000 | - |
| scs-lazy | normal | rune:opt | O2 | count | 1/1 | 45.470000000 | 45.470000000 to 45.470000000 | 24079670053/37072526520/1004260753 |
| scs-lazy | normal | rune:new | O2 | compile | 1/1 | 3.090000000 | 3.090000000 to 3.090000000 | - |
| scs-lazy | normal | rune:new | O2 | correctness | 1/1 | 90.630000000 | 90.630000000 to 90.630000000 | - |
| scs-lazy | normal | rune:new | O2 | count | 1/1 | 99.950000000 | 99.950000000 to 99.950000000 | 14207308284/37072526520/1004260753 |
| scs-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.840000000 | 2.840000000 to 2.840000000 | - |
| scs-lazy | normal | rune:jit | O2 | correctness | 1/1 | 40.350000000 | 40.350000000 to 40.350000000 | - |
| scs-lazy | normal | rune:jit | O2 | count | 1/1 | 38.220000000 | 38.220000000 to 38.220000000 | 14207308284/37072526520/1004260753 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

