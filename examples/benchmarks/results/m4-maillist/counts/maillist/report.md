# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| maillist | normal | rune | O2 | compile | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |
| maillist | normal | rune | O2 | correctness | 1/1 | 2.130000000 | 2.130000000 to 2.130000000 | - |
| maillist | normal | rune | O2 | count | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | 94250114/377399464/8420455 |
| maillist | normal | rune:opt | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| maillist | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| maillist | normal | rune:opt | O2 | correctness | 1/1 | 1.860000000 | 1.860000000 to 1.860000000 | - |
| maillist | normal | rune:opt | O2 | count | 1/1 | 1.660000000 | 1.660000000 to 1.660000000 | 94250114/377399464/8420455 |
| maillist | normal | rune:new | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| maillist | normal | rune:new | O2 | correctness | 1/1 | 2.690000000 | 2.690000000 to 2.690000000 | - |
| maillist | normal | rune:new | O2 | count | 1/1 | 4.300000000 | 4.300000000 to 4.300000000 | 52242146/377399464/8420455 |
| maillist | normal | rune:jit | O2 | compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| maillist | normal | rune:jit | O2 | correctness | 1/1 | 1.910000000 | 1.910000000 to 1.910000000 | - |
| maillist | normal | rune:jit | O2 | count | 1/1 | 1.720000000 | 1.720000000 to 1.720000000 | 52242146/377399464/8420455 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

