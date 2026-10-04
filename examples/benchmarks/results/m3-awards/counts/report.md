# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| awards-lazy | normal | rune | O2 | compile | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |
| awards-lazy | normal | rune | O2 | correctness | 1/1 | 5.920000000 | 5.920000000 to 5.920000000 | - |
| awards-lazy | normal | rune | O2 | count | 1/1 | 5.680000000 | 5.680000000 to 5.680000000 | 674090247/2250045712/68662668 |
| awards-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.060000000 | 3.060000000 to 3.060000000 | - |
| awards-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| awards-lazy | normal | rune:opt | O2 | correctness | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |
| awards-lazy | normal | rune:opt | O2 | count | 1/1 | 1.710000000 | 1.710000000 to 1.710000000 | 674090247/2250045712/68662668 |
| awards-lazy | normal | rune:new | O2 | compile | 1/1 | 2.620000000 | 2.620000000 to 2.620000000 | - |
| awards-lazy | normal | rune:new | O2 | correctness | 1/1 | 3.280000000 | 3.280000000 to 3.280000000 | - |
| awards-lazy | normal | rune:new | O2 | count | 1/1 | 4.980000000 | 4.980000000 to 4.980000000 | 396363898/2250045712/68662668 |
| awards-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.630000000 | 3.630000000 to 3.630000000 | - |
| awards-lazy | normal | rune:jit | O2 | correctness | 1/1 | 1.720000000 | 1.720000000 to 1.720000000 | - |
| awards-lazy | normal | rune:jit | O2 | count | 1/1 | 1.550000000 | 1.550000000 to 1.550000000 | 396363898/2250045712/68662668 |
| awards-strict | normal | rune | O2 | compile | 1/1 | 2.460000000 | 2.460000000 to 2.460000000 | - |
| awards-strict | normal | rune | O2 | correctness | 1/1 | 3.990000000 | 3.990000000 to 3.990000000 | - |
| awards-strict | normal | rune | O2 | count | 1/1 | 3.230000000 | 3.230000000 to 3.230000000 | 638058855/1335396520/33392205 |
| awards-strict | normal | rune:opt | O2 | compile | 1/1 | 3.070000000 | 3.070000000 to 3.070000000 | - |
| awards-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| awards-strict | normal | rune:opt | O2 | correctness | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| awards-strict | normal | rune:opt | O2 | count | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | 638058855/1335396520/33392205 |
| awards-strict | normal | rune:new | O2 | compile | 1/1 | 1.580000000 | 1.580000000 to 1.580000000 | - |
| awards-strict | normal | rune:new | O2 | correctness | 1/1 | 3.510000000 | 3.510000000 to 3.510000000 | - |
| awards-strict | normal | rune:new | O2 | count | 1/1 | 3.360000000 | 3.360000000 to 3.360000000 | 311750396/1335396520/33392205 |
| awards-strict | normal | rune:jit | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| awards-strict | normal | rune:jit | O2 | correctness | 1/1 | 1.020000000 | 1.020000000 to 1.020000000 | - |
| awards-strict | normal | rune:jit | O2 | count | 1/1 | 1.080000000 | 1.080000000 to 1.080000000 | 311750396/1335396520/33392205 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

