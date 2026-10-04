# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| CSD | normal | rune | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| CSD | normal | rune | O2 | correctness | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | - |
| CSD | normal | rune | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 44010467/192019096/4000501 |
| CSD | normal | rune:opt | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| CSD | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| CSD | normal | rune:opt | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| CSD | normal | rune:opt | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 44010467/192019096/4000501 |
| CSD | normal | rune:new | O2 | compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| CSD | normal | rune:new | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| CSD | normal | rune:new | O2 | count | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | 30006348/192019096/4000501 |
| CSD | normal | rune:jit | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| CSD | normal | rune:jit | O2 | correctness | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| CSD | normal | rune:jit | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 30006348/192019096/4000501 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

