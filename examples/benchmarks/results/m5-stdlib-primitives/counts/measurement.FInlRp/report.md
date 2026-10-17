# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| pervasives_equal_ints | normal | rune | O2 | compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| pervasives_equal_ints | normal | rune | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| pervasives_equal_ints | normal | rune | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 5010885/20272/530 |
| pervasives_equal_ints | normal | rune:opt | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| pervasives_equal_ints | normal | rune:opt | O2 | native-compile | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| pervasives_equal_ints | normal | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| pervasives_equal_ints | normal | rune:opt | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 5010885/20272/530 |
| pervasives_equal_ints | normal | rune:new | O2 | compile | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| pervasives_equal_ints | normal | rune:new | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| pervasives_equal_ints | normal | rune:new | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 3706653/20272/530 |
| pervasives_equal_ints | normal | rune:jit | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| pervasives_equal_ints | normal | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| pervasives_equal_ints | normal | rune:jit | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 3706653/20272/530 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

