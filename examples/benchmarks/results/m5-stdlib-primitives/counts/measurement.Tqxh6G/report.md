# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| pervasives_compare_lists | normal | rune | O2 | compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| pervasives_compare_lists | normal | rune | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| pervasives_compare_lists | normal | rune | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 7211037/20400/530 |
| pervasives_compare_lists | normal | rune:opt | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| pervasives_compare_lists | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| pervasives_compare_lists | normal | rune:opt | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| pervasives_compare_lists | normal | rune:opt | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 7211037/20400/530 |
| pervasives_compare_lists | normal | rune:new | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| pervasives_compare_lists | normal | rune:new | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| pervasives_compare_lists | normal | rune:new | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 4706756/20400/530 |
| pervasives_compare_lists | normal | rune:jit | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| pervasives_compare_lists | normal | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| pervasives_compare_lists | normal | rune:jit | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 4706756/20400/530 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

