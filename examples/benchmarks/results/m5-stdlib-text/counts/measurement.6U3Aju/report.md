# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_map | normal | rune | O2 | compile | 1/1 | 3.240000000 | 3.240000000 to 3.240000000 | - |
| bytes_map | normal | rune | O2 | correctness | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | - |
| bytes_map | normal | rune | O2 | count | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | 117413741/202378208/4603280 |
| bytes_map | normal | rune:opt | O2 | compile | 1/1 | 3.600000000 | 3.600000000 to 3.600000000 | - |
| bytes_map | normal | rune:opt | O2 | native-compile | 1/1 | 0.920000000 | 0.920000000 to 0.920000000 | - |
| bytes_map | normal | rune:opt | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| bytes_map | normal | rune:opt | O2 | count | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | 117413741/202378208/4603280 |
| bytes_map | normal | rune:new | O2 | compile | 1/1 | 3.030000000 | 3.030000000 to 3.030000000 | - |
| bytes_map | normal | rune:new | O2 | correctness | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| bytes_map | normal | rune:new | O2 | count | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | 82867121/202378208/4603280 |
| bytes_map | normal | rune:jit | O2 | compile | 1/1 | 4.250000000 | 4.250000000 to 4.250000000 | - |
| bytes_map | normal | rune:jit | O2 | correctness | 1/1 | 0.660000000 | 0.660000000 to 0.660000000 | - |
| bytes_map | normal | rune:jit | O2 | count | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | 82867121/202378208/4603280 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

