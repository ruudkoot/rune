# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| scs-strict | normal | rune | O2 | compile | 1/1 | 3.020000000 | 3.020000000 to 3.020000000 | - |
| scs-strict | normal | rune | O2 | correctness | 1/1 | 129.260000000 | 129.260000000 to 129.260000000 | - |
| scs-strict | normal | rune | O2 | count | 1/1 | 123.700000000 | 123.700000000 to 123.700000000 | 25006300409/37689422680/1024841997 |
| scs-strict | normal | rune:opt | O2 | compile | 1/1 | 3.060000000 | 3.060000000 to 3.060000000 | - |
| scs-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | - |
| scs-strict | normal | rune:opt | O2 | correctness | 1/1 | 44.630000000 | 44.630000000 to 44.630000000 | - |
| scs-strict | normal | rune:opt | O2 | count | 1/1 | 46.700000000 | 46.700000000 to 46.700000000 | 25006300409/37689422680/1024841997 |
| scs-strict | normal | rune:new | O2 | compile | 1/1 | 3.070000000 | 3.070000000 to 3.070000000 | - |
| scs-strict | normal | rune:new | O2 | correctness | 1/1 | 102.180000000 | 102.180000000 to 102.180000000 | - |
| scs-strict | normal | rune:new | O2 | count | 1/1 | 103.160000000 | 103.160000000 to 103.160000000 | 14768386004/37689422680/1024841997 |
| scs-strict | normal | rune:jit | O2 | compile | 1/1 | 5.030000000 | 5.030000000 to 5.030000000 | - |
| scs-strict | normal | rune:jit | O2 | correctness | 1/1 | 34.430000000 | 34.430000000 to 34.430000000 | - |
| scs-strict | normal | rune:jit | O2 | count | 1/1 | 40.360000000 | 40.360000000 to 40.360000000 | 14768386004/37689422680/1024841997 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

