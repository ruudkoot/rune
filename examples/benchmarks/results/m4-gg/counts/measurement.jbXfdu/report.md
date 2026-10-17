# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gg-spark-strict | normal | rune | O2 | compile | 1/1 | 3.130000000 | 3.130000000 to 3.130000000 | - |
| gg-spark-strict | normal | rune | O2 | correctness | 1/1 | 37.690000000 | 37.690000000 to 37.690000000 | - |
| gg-spark-strict | normal | rune | O2 | count | 1/1 | 37.300000000 | 37.300000000 to 37.300000000 | 6935169659/15791316384/457200988 |
| gg-spark-strict | normal | rune:opt | O2 | compile | 1/1 | 3.450000000 | 3.450000000 to 3.450000000 | - |
| gg-spark-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.800000000 | 0.800000000 to 0.800000000 | - |
| gg-spark-strict | normal | rune:opt | O2 | correctness | 1/1 | 19.850000000 | 19.850000000 to 19.850000000 | - |
| gg-spark-strict | normal | rune:opt | O2 | count | 1/1 | 17.500000000 | 17.500000000 to 17.500000000 | 6935169659/15791316384/457200988 |
| gg-spark-strict | normal | rune:new | O2 | compile | 1/1 | 3.010000000 | 3.010000000 to 3.010000000 | - |
| gg-spark-strict | normal | rune:new | O2 | correctness | 1/1 | 37.920000000 | 37.920000000 to 37.920000000 | - |
| gg-spark-strict | normal | rune:new | O2 | count | 1/1 | 36.420000000 | 36.420000000 to 36.420000000 | 3994514946/15791316384/457200988 |
| gg-spark-strict | normal | rune:jit | O2 | compile | 1/1 | 2.710000000 | 2.710000000 to 2.710000000 | - |
| gg-spark-strict | normal | rune:jit | O2 | correctness | 1/1 | 16.750000000 | 16.750000000 to 16.750000000 | - |
| gg-spark-strict | normal | rune:jit | O2 | count | 1/1 | 16.680000000 | 16.680000000 to 16.680000000 | 3994514946/15791316384/457200988 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

