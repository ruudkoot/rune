# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| cryptarithm2-lazy | normal | rune | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| cryptarithm2-lazy | normal | rune | O2 | correctness | 1/1 | 53.330000000 | 53.330000000 to 53.330000000 | - |
| cryptarithm2-lazy | normal | rune | O2 | count | 1/1 | 53.550000000 | 53.550000000 to 53.550000000 | 11505768975/37511653112/1137402723 |
| cryptarithm2-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| cryptarithm2-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| cryptarithm2-lazy | normal | rune:opt | O2 | correctness | 1/1 | 25.320000000 | 25.320000000 to 25.320000000 | - |
| cryptarithm2-lazy | normal | rune:opt | O2 | count | 1/1 | 25.530000000 | 25.530000000 to 25.530000000 | 11505768975/37511653112/1137402723 |
| cryptarithm2-lazy | normal | rune:new | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| cryptarithm2-lazy | normal | rune:new | O2 | correctness | 1/1 | 51.170000000 | 51.170000000 to 51.170000000 | - |
| cryptarithm2-lazy | normal | rune:new | O2 | count | 1/1 | 51.590000000 | 51.590000000 to 51.590000000 | 6821102708/37511653112/1137402723 |
| cryptarithm2-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| cryptarithm2-lazy | normal | rune:jit | O2 | correctness | 1/1 | 25.050000000 | 25.050000000 to 25.050000000 | - |
| cryptarithm2-lazy | normal | rune:jit | O2 | count | 1/1 | 24.000000000 | 24.000000000 to 24.000000000 | 6821102708/37511653112/1137402723 |
| cryptarithm2-strict | normal | rune | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| cryptarithm2-strict | normal | rune | O2 | correctness | 1/1 | 26.580000000 | 26.580000000 to 26.580000000 | - |
| cryptarithm2-strict | normal | rune | O2 | count | 1/1 | 27.020000000 | 27.020000000 to 27.020000000 | 7083326228/20268257632/484652126 |
| cryptarithm2-strict | normal | rune:opt | O2 | compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| cryptarithm2-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| cryptarithm2-strict | normal | rune:opt | O2 | correctness | 1/1 | 11.220000000 | 11.220000000 to 11.220000000 | - |
| cryptarithm2-strict | normal | rune:opt | O2 | count | 1/1 | 12.490000000 | 12.490000000 to 12.490000000 | 7083326228/20268257632/484652126 |
| cryptarithm2-strict | normal | rune:new | O2 | compile | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| cryptarithm2-strict | normal | rune:new | O2 | correctness | 1/1 | 29.630000000 | 29.630000000 to 29.630000000 | - |
| cryptarithm2-strict | normal | rune:new | O2 | count | 1/1 | 32.720000000 | 32.720000000 to 32.720000000 | 3847711788/20268257632/484652126 |
| cryptarithm2-strict | normal | rune:jit | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| cryptarithm2-strict | normal | rune:jit | O2 | correctness | 1/1 | 12.890000000 | 12.890000000 to 12.890000000 | - |
| cryptarithm2-strict | normal | rune:jit | O2 | count | 1/1 | 11.670000000 | 11.670000000 to 11.670000000 | 3847711788/20268257632/484652126 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

