# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| awards-lazy | normal | rune | O2 | configuration | 0/1 | - | - | - |
| awards-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.660000000 | 1.660000000 to 1.660000000 | - |
| awards-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.510000000 | 0.510000000 to 0.510000000 | - |
| awards-lazy | normal | rune:opt | O2 | correctness | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| awards-lazy | normal | rune:opt | O2 | count | 1/1 | 2.050000000 | 2.050000000 to 2.050000000 | 674090247/2250045712/68662668 |
| awards-lazy | normal | rune:new | O2 | compile | 1/1 | 2.600000000 | 2.600000000 to 2.600000000 | - |
| awards-lazy | normal | rune:new | O2 | correctness | 1/1 | 6.540000000 | 6.540000000 to 6.540000000 | - |
| awards-lazy | normal | rune:new | O2 | count | 1/1 | 4.410000000 | 4.410000000 to 4.410000000 | 396363898/2250045712/68662668 |
| awards-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| awards-lazy | normal | rune:jit | O2 | correctness | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| awards-lazy | normal | rune:jit | O2 | count | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | 396363898/2250045712/68662668 |
| awards-strict | normal | rune | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| awards-strict | normal | rune | O2 | correctness | 1/1 | 2.340000000 | 2.340000000 to 2.340000000 | - |
| awards-strict | normal | rune | O2 | count | 1/1 | 2.760000000 | 2.760000000 to 2.760000000 | 638058855/1335396520/33392205 |
| awards-strict | normal | rune:opt | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| awards-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| awards-strict | normal | rune:opt | O2 | correctness | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |
| awards-strict | normal | rune:opt | O2 | count | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | 638058855/1335396520/33392205 |
| awards-strict | normal | rune:new | O2 | compile | 1/1 | 1.400000000 | 1.400000000 to 1.400000000 | - |
| awards-strict | normal | rune:new | O2 | correctness | 1/1 | 2.100000000 | 2.100000000 to 2.100000000 | - |
| awards-strict | normal | rune:new | O2 | count | 1/1 | 3.080000000 | 3.080000000 to 3.080000000 | 311750396/1335396520/33392205 |
| awards-strict | normal | rune:jit | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| awards-strict | normal | rune:jit | O2 | correctness | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |
| awards-strict | normal | rune:jit | O2 | count | 1/1 | 0.980000000 | 0.980000000 to 0.980000000 | 311750396/1335396520/33392205 |

Failure categories and artifact paths:

- awards-lazy / rune / configuration: missing-configuration (`awards-lazy/rune`).
