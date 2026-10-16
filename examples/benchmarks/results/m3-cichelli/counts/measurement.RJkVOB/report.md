# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| cichelli-lazy | normal | rune | O2 | compile | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |
| cichelli-lazy | normal | rune | O2 | correctness | 1/1 | 19.560000000 | 19.560000000 to 19.560000000 | - |
| cichelli-lazy | normal | rune | O2 | count | 1/1 | 15.750000000 | 15.750000000 to 15.750000000 | 3891701890/5255398800/155016074 |
| cichelli-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | - |
| cichelli-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| cichelli-lazy | normal | rune:opt | O2 | correctness | 1/1 | 6.730000000 | 6.730000000 to 6.730000000 | - |
| cichelli-lazy | normal | rune:opt | O2 | count | 1/1 | 6.360000000 | 6.360000000 to 6.360000000 | 3891701890/5255398800/155016074 |
| cichelli-lazy | normal | rune:new | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| cichelli-lazy | normal | rune:new | O2 | correctness | 1/1 | 12.990000000 | 12.990000000 to 12.990000000 | - |
| cichelli-lazy | normal | rune:new | O2 | count | 1/1 | 15.240000000 | 15.240000000 to 15.240000000 | 2059989775/5255398800/155016074 |
| cichelli-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| cichelli-lazy | normal | rune:jit | O2 | correctness | 1/1 | 6.230000000 | 6.230000000 to 6.230000000 | - |
| cichelli-lazy | normal | rune:jit | O2 | count | 1/1 | 6.020000000 | 6.020000000 to 6.020000000 | 2059989775/5255398800/155016074 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

