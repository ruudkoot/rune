# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hidden-strict | normal | rune | O2 | compile | 1/1 | 2.110000000 | 2.110000000 to 2.110000000 | - |
| hidden-strict | normal | rune | O2 | correctness | 1/1 | 168.900000000 | 168.900000000 to 168.900000000 | - |
| hidden-strict | normal | rune | O2 | count | 1/1 | 178.990000000 | 178.990000000 to 178.990000000 | 26585462016/30974431832/961411449 |
| hidden-strict | normal | rune:opt | O2 | compile | 1/1 | 2.480000000 | 2.480000000 to 2.480000000 | - |
| hidden-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | - |
| hidden-strict | normal | rune:opt | O2 | correctness | 1/1 | 87.060000000 | 87.060000000 to 87.060000000 | - |
| hidden-strict | normal | rune:opt | O2 | count | 1/1 | 96.340000000 | 96.340000000 to 96.340000000 | 26585462016/30974431832/961411449 |
| hidden-strict | normal | rune:new | O2 | compile | 1/1 | 3.250000000 | 3.250000000 to 3.250000000 | - |
| hidden-strict | normal | rune:new | O2 | correctness | 1/1 | 169.850000000 | 169.850000000 to 169.850000000 | - |
| hidden-strict | normal | rune:new | O2 | count | 1/1 | 137.610000000 | 137.610000000 to 137.610000000 | 16101412400/30974431832/961411449 |
| hidden-strict | normal | rune:jit | O2 | compile | 1/1 | 1.720000000 | 1.720000000 to 1.720000000 | - |
| hidden-strict | normal | rune:jit | O2 | correctness | 1/1 | 62.330000000 | 62.330000000 to 62.330000000 | - |
| hidden-strict | normal | rune:jit | O2 | count | 1/1 | 71.730000000 | 71.730000000 to 71.730000000 | 16101412400/30974431832/961411449 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

