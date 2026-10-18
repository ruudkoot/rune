# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| map_add | normal | rune | O2 | compile | 1/1 | 4.510000000 | 4.510000000 to 4.510000000 | - |
| map_add | normal | rune | O2 | correctness | 1/1 | 3.900000000 | 3.900000000 to 3.900000000 | - |
| map_add | normal | rune | O2 | count | 1/1 | 4.030000000 | 4.030000000 to 4.030000000 | 236279083/239898120/4255511 |
| map_add | normal | rune:opt | O2 | compile | 1/1 | 5.880000000 | 5.880000000 to 5.880000000 | - |
| map_add | normal | rune:opt | O2 | native-compile | 1/1 | 0.890000000 | 0.890000000 to 0.890000000 | - |
| map_add | normal | rune:opt | O2 | correctness | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |
| map_add | normal | rune:opt | O2 | count | 1/1 | 1.730000000 | 1.730000000 to 1.730000000 | 236279083/239898120/4255511 |
| map_add | normal | rune:new | O2 | compile | 1/1 | 3.350000000 | 3.350000000 to 3.350000000 | - |
| map_add | normal | rune:new | O2 | correctness | 1/1 | 2.230000000 | 2.230000000 to 2.230000000 | - |
| map_add | normal | rune:new | O2 | count | 1/1 | 3.040000000 | 3.040000000 to 3.040000000 | 125776690/239898120/4255511 |
| map_add | normal | rune:jit | O2 | compile | 1/1 | 7.530000000 | 7.530000000 to 7.530000000 | - |
| map_add | normal | rune:jit | O2 | correctness | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| map_add | normal | rune:jit | O2 | count | 1/1 | 1.920000000 | 1.920000000 to 1.920000000 | 125776690/239898120/4255511 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

