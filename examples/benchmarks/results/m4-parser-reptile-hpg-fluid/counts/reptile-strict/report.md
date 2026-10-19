# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| reptile-strict | normal | rune | O2 | compile | 1/1 | 3.440000000 | 3.440000000 to 3.440000000 | - |
| reptile-strict | normal | rune | O2 | correctness | 1/1 | 14.900000000 | 14.900000000 to 14.900000000 | - |
| reptile-strict | normal | rune | O2 | count | 1/1 | 17.020000000 | 17.020000000 to 17.020000000 | 2353540968/6256692152/155655633 |
| reptile-strict | normal | rune:opt | O2 | compile | 1/1 | 3.380000000 | 3.380000000 to 3.380000000 | - |
| reptile-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| reptile-strict | normal | rune:opt | O2 | correctness | 1/1 | 8.480000000 | 8.480000000 to 8.480000000 | - |
| reptile-strict | normal | rune:opt | O2 | count | 1/1 | 10.610000000 | 10.610000000 to 10.610000000 | 2353540968/6256692152/155655633 |
| reptile-strict | normal | rune:new | O2 | compile | 1/1 | 3.890000000 | 3.890000000 to 3.890000000 | - |
| reptile-strict | normal | rune:new | O2 | correctness | 1/1 | 15.280000000 | 15.280000000 to 15.280000000 | - |
| reptile-strict | normal | rune:new | O2 | count | 1/1 | 17.390000000 | 17.390000000 to 17.390000000 | 1410447816/6256692152/155655633 |
| reptile-strict | normal | rune:jit | O2 | compile | 1/1 | 3.960000000 | 3.960000000 to 3.960000000 | - |
| reptile-strict | normal | rune:jit | O2 | correctness | 1/1 | 7.480000000 | 7.480000000 to 7.480000000 | - |
| reptile-strict | normal | rune:jit | O2 | count | 1/1 | 7.060000000 | 7.060000000 to 7.060000000 | 1410447816/6256692152/155655633 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

