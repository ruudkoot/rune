# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| constraints-lazy | normal | rune | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| constraints-lazy | normal | rune | O2 | correctness | 1/1 | 12.420000000 | 12.420000000 to 12.420000000 | - |
| constraints-lazy | normal | rune | O2 | count | 1/1 | 9.480000000 | 9.480000000 to 9.480000000 | 1726767226/6092889816/182328963 |
| constraints-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| constraints-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| constraints-lazy | normal | rune:opt | O2 | correctness | 1/1 | 5.300000000 | 5.300000000 to 5.300000000 | - |
| constraints-lazy | normal | rune:opt | O2 | count | 1/1 | 4.450000000 | 4.450000000 to 4.450000000 | 1726767226/6092889816/182328963 |
| constraints-lazy | normal | rune:new | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| constraints-lazy | normal | rune:new | O2 | correctness | 1/1 | 7.560000000 | 7.560000000 to 7.560000000 | - |
| constraints-lazy | normal | rune:new | O2 | count | 1/1 | 7.790000000 | 7.790000000 to 7.790000000 | 1030918963/6092889816/182328963 |
| constraints-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.400000000 | 1.400000000 to 1.400000000 | - |
| constraints-lazy | normal | rune:jit | O2 | correctness | 1/1 | 3.580000000 | 3.580000000 to 3.580000000 | - |
| constraints-lazy | normal | rune:jit | O2 | count | 1/1 | 4.760000000 | 4.760000000 to 4.760000000 | 1030918963/6092889816/182328963 |
| constraints-strict | normal | rune | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| constraints-strict | normal | rune | O2 | correctness | 1/1 | 224.120000000 | 224.120000000 to 224.120000000 | - |
| constraints-strict | normal | rune | O2 | count | 1/1 | 236.790000000 | 236.790000000 to 236.790000000 | 45628908612/101553381288/2548960319 |
| constraints-strict | normal | rune:opt | O2 | compile | 1/1 | 1.730000000 | 1.730000000 to 1.730000000 | - |
| constraints-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.550000000 | 0.550000000 to 0.550000000 | - |
| constraints-strict | normal | rune:opt | O2 | correctness | 1/1 | 116.290000000 | 116.290000000 to 116.290000000 | - |
| constraints-strict | normal | rune:opt | O2 | count | 1/1 | 130.780000000 | 130.780000000 to 130.780000000 | 45628908612/101553381288/2548960319 |
| constraints-strict | normal | rune:new | O2 | compile | 1/1 | 1.770000000 | 1.770000000 to 1.770000000 | - |
| constraints-strict | normal | rune:new | O2 | correctness | 1/1 | 240.850000000 | 240.850000000 to 240.850000000 | - |
| constraints-strict | normal | rune:new | O2 | count | 1/1 | 245.360000000 | 245.360000000 to 245.360000000 | 25266526259/101553381288/2548960319 |
| constraints-strict | normal | rune:jit | O2 | compile | 1/1 | 1.850000000 | 1.850000000 to 1.850000000 | - |
| constraints-strict | normal | rune:jit | O2 | correctness | 1/1 | 128.270000000 | 128.270000000 to 128.270000000 | - |
| constraints-strict | normal | rune:jit | O2 | count | 1/1 | 109.300000000 | 109.300000000 to 109.300000000 | 25266526259/101553381288/2548960319 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

