# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fish-lazy | normal | rune | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| fish-lazy | normal | rune | O2 | correctness | 1/1 | 84.300000000 | 84.300000000 to 84.300000000 | - |
| fish-lazy | normal | rune | O2 | count | 1/1 | 75.900000000 | 75.900000000 to 75.900000000 | 16919706229/61825377400/1929025371 |
| fish-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| fish-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| fish-lazy | normal | rune:opt | O2 | correctness | 1/1 | 37.850000000 | 37.850000000 to 37.850000000 | - |
| fish-lazy | normal | rune:opt | O2 | count | 1/1 | 38.160000000 | 38.160000000 to 38.160000000 | 16919706229/61825377400/1929025371 |
| fish-lazy | normal | rune:new | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| fish-lazy | normal | rune:new | O2 | correctness | 1/1 | 86.630000000 | 86.630000000 to 86.630000000 | - |
| fish-lazy | normal | rune:new | O2 | count | 1/1 | 87.290000000 | 87.290000000 to 87.290000000 | 10312860328/61825377400/1929025371 |
| fish-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| fish-lazy | normal | rune:jit | O2 | correctness | 1/1 | 51.570000000 | 51.570000000 to 51.570000000 | - |
| fish-lazy | normal | rune:jit | O2 | count | 1/1 | 50.130000000 | 50.130000000 to 50.130000000 | 10312860328/61825377400/1929025371 |
| fish-strict | normal | rune | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| fish-strict | normal | rune | O2 | correctness | 1/1 | 16.860000000 | 16.860000000 to 16.860000000 | - |
| fish-strict | normal | rune | O2 | count | 1/1 | 19.760000000 | 19.760000000 to 19.760000000 | 3662280698/9495360880/234538580 |
| fish-strict | normal | rune:opt | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| fish-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| fish-strict | normal | rune:opt | O2 | correctness | 1/1 | 8.040000000 | 8.040000000 to 8.040000000 | - |
| fish-strict | normal | rune:opt | O2 | count | 1/1 | 8.150000000 | 8.150000000 to 8.150000000 | 3662280698/9495360880/234538580 |
| fish-strict | normal | rune:new | O2 | compile | 1/1 | 1.730000000 | 1.730000000 to 1.730000000 | - |
| fish-strict | normal | rune:new | O2 | correctness | 1/1 | 18.860000000 | 18.860000000 to 18.860000000 | - |
| fish-strict | normal | rune:new | O2 | count | 1/1 | 19.310000000 | 19.310000000 to 19.310000000 | 2294780770/9495360880/234538580 |
| fish-strict | normal | rune:jit | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| fish-strict | normal | rune:jit | O2 | correctness | 1/1 | 10.250000000 | 10.250000000 to 10.250000000 | - |
| fish-strict | normal | rune:jit | O2 | count | 1/1 | 9.100000000 | 9.100000000 to 9.100000000 | 2294780770/9495360880/234538580 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

