# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mkhprog-strict | normal | rune | O2 | compile | 1/1 | 1.910000000 | 1.910000000 to 1.910000000 | - |
| mkhprog-strict | normal | rune | O2 | correctness | 1/1 | 28.020000000 | 28.020000000 to 28.020000000 | - |
| mkhprog-strict | normal | rune | O2 | count | 1/1 | 28.620000000 | 28.620000000 to 28.620000000 | 5434717082/13733891064/354194735 |
| mkhprog-strict | normal | rune:opt | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| mkhprog-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| mkhprog-strict | normal | rune:opt | O2 | correctness | 1/1 | 12.360000000 | 12.360000000 to 12.360000000 | - |
| mkhprog-strict | normal | rune:opt | O2 | count | 1/1 | 12.810000000 | 12.810000000 to 12.810000000 | 5434717082/13733891064/354194735 |
| mkhprog-strict | normal | rune:new | O2 | compile | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| mkhprog-strict | normal | rune:new | O2 | correctness | 1/1 | 29.440000000 | 29.440000000 to 29.440000000 | - |
| mkhprog-strict | normal | rune:new | O2 | count | 1/1 | 28.130000000 | 28.130000000 to 28.130000000 | 3179021886/13733891064/354194735 |
| mkhprog-strict | normal | rune:jit | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| mkhprog-strict | normal | rune:jit | O2 | correctness | 1/1 | 12.510000000 | 12.510000000 to 12.510000000 | - |
| mkhprog-strict | normal | rune:jit | O2 | count | 1/1 | 14.690000000 | 14.690000000 to 14.690000000 | 3179021886/13733891064/354194735 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

