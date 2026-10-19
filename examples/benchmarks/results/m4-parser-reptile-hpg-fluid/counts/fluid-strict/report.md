# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fluid-strict | normal | rune | O2 | compile | 1/1 | 5.240000000 | 5.240000000 to 5.240000000 | - |
| fluid-strict | normal | rune | O2 | correctness | 1/1 | 28.480000000 | 28.480000000 to 28.480000000 | - |
| fluid-strict | normal | rune | O2 | count | 1/1 | 32.140000000 | 32.140000000 to 32.140000000 | 3227830205/5428137056/157888824 |
| fluid-strict | normal | rune:opt | O2 | compile | 1/1 | 5.880000000 | 5.880000000 to 5.880000000 | - |
| fluid-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| fluid-strict | normal | rune:opt | O2 | correctness | 1/1 | 10.010000000 | 10.010000000 to 10.010000000 | - |
| fluid-strict | normal | rune:opt | O2 | count | 1/1 | 9.610000000 | 9.610000000 to 9.610000000 | 3227830205/5428137056/157888824 |
| fluid-strict | normal | rune:new | O2 | compile | 1/1 | 4.350000000 | 4.350000000 to 4.350000000 | - |
| fluid-strict | normal | rune:new | O2 | correctness | 1/1 | 21.390000000 | 21.390000000 to 21.390000000 | - |
| fluid-strict | normal | rune:new | O2 | count | 1/1 | 20.550000000 | 20.550000000 to 20.550000000 | 1851708563/5428137056/157888824 |
| fluid-strict | normal | rune:jit | O2 | compile | 1/1 | 4.000000000 | 4.000000000 to 4.000000000 | - |
| fluid-strict | normal | rune:jit | O2 | correctness | 1/1 | 10.260000000 | 10.260000000 to 10.260000000 | - |
| fluid-strict | normal | rune:jit | O2 | count | 1/1 | 9.040000000 | 9.040000000 to 9.040000000 | 1851708563/5428137056/157888824 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

