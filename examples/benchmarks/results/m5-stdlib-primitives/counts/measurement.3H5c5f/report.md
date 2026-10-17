# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| pervasives_compare_strings | normal | rune | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| pervasives_compare_strings | normal | rune | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| pervasives_compare_strings | normal | rune | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 4911082/2420400/100530 |
| pervasives_compare_strings | normal | rune:opt | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| pervasives_compare_strings | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| pervasives_compare_strings | normal | rune:opt | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| pervasives_compare_strings | normal | rune:opt | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 4911082/2420400/100530 |
| pervasives_compare_strings | normal | rune:new | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| pervasives_compare_strings | normal | rune:new | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| pervasives_compare_strings | normal | rune:new | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 3606787/2420400/100530 |
| pervasives_compare_strings | normal | rune:jit | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| pervasives_compare_strings | normal | rune:jit | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| pervasives_compare_strings | normal | rune:jit | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 3606787/2420400/100530 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

