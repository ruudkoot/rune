# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| cichelli-strict | normal | rune | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| cichelli-strict | normal | rune | O2 | correctness | 1/1 | 13.530000000 | 13.530000000 to 13.530000000 | - |
| cichelli-strict | normal | rune | O2 | count | 1/1 | 11.470000000 | 11.470000000 to 11.470000000 | 3715856916/4537240968/134318471 |
| cichelli-strict | normal | rune:opt | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| cichelli-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| cichelli-strict | normal | rune:opt | O2 | correctness | 1/1 | 4.470000000 | 4.470000000 to 4.470000000 | - |
| cichelli-strict | normal | rune:opt | O2 | count | 1/1 | 4.470000000 | 4.470000000 to 4.470000000 | 3715856916/4537240968/134318471 |
| cichelli-strict | normal | rune:new | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| cichelli-strict | normal | rune:new | O2 | correctness | 1/1 | 11.500000000 | 11.500000000 to 11.500000000 | - |
| cichelli-strict | normal | rune:new | O2 | count | 1/1 | 9.470000000 | 9.470000000 to 9.470000000 | 1935830351/4537240968/134318471 |
| cichelli-strict | normal | rune:jit | O2 | compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| cichelli-strict | normal | rune:jit | O2 | correctness | 1/1 | 3.520000000 | 3.520000000 to 3.520000000 | - |
| cichelli-strict | normal | rune:jit | O2 | count | 1/1 | 3.570000000 | 3.570000000 to 3.570000000 | 1935830351/4537240968/134318471 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

