# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| constraints-lazy | normal | rune | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| constraints-lazy | normal | rune | O2 | correctness | 1/1 | 7.430000000 | 7.430000000 to 7.430000000 | - |
| constraints-lazy | normal | rune | O2 | count | 1/1 | 7.530000000 | 7.530000000 to 7.530000000 | 1726767226/6092889816/182328963 |
| constraints-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| constraints-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| constraints-lazy | normal | rune:opt | O2 | correctness | 1/1 | 3.870000000 | 3.870000000 to 3.870000000 | - |
| constraints-lazy | normal | rune:opt | O2 | count | 1/1 | 3.760000000 | 3.760000000 to 3.760000000 | 1726767226/6092889816/182328963 |
| constraints-lazy | normal | rune:new | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| constraints-lazy | normal | rune:new | O2 | correctness | 1/1 | 8.580000000 | 8.580000000 to 8.580000000 | - |
| constraints-lazy | normal | rune:new | O2 | count | 1/1 | 7.030000000 | 7.030000000 to 7.030000000 | 1030918963/6092889816/182328963 |
| constraints-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| constraints-lazy | normal | rune:jit | O2 | correctness | 1/1 | 3.490000000 | 3.490000000 to 3.490000000 | - |
| constraints-lazy | normal | rune:jit | O2 | count | 1/1 | 3.430000000 | 3.430000000 to 3.430000000 | 1030918963/6092889816/182328963 |
| constraints-strict | normal | rune | O2 | compile | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| constraints-strict | normal | rune | O2 | correctness | 1/1 | 208.590000000 | 208.590000000 to 208.590000000 | - |
| constraints-strict | normal | rune | O2 | count | 1/1 | 210.820000000 | 210.820000000 to 210.820000000 | 45628908612/101553381288/2548960319 |
| constraints-strict | normal | rune:opt | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| constraints-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| constraints-strict | normal | rune:opt | O2 | correctness | 1/1 | 110.980000000 | 110.980000000 to 110.980000000 | - |
| constraints-strict | normal | rune:opt | O2 | count | 1/1 | 112.120000000 | 112.120000000 to 112.120000000 | 45628908612/101553381288/2548960319 |
| constraints-strict | normal | rune:new | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| constraints-strict | normal | rune:new | O2 | correctness | 1/1 | 204.330000000 | 204.330000000 to 204.330000000 | - |
| constraints-strict | normal | rune:new | O2 | count | 1/1 | 203.800000000 | 203.800000000 to 203.800000000 | 25266526259/101553381288/2548960319 |
| constraints-strict | normal | rune:jit | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| constraints-strict | normal | rune:jit | O2 | correctness | 1/1 | 111.820000000 | 111.820000000 to 111.820000000 | - |
| constraints-strict | normal | rune:jit | O2 | count | 1/1 | 110.160000000 | 110.160000000 to 110.160000000 | 25266526259/101553381288/2548960319 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

