# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lambda-simple-lazy | normal | rune | O2 | compile | 1/1 | 2.220000000 | 2.220000000 to 2.220000000 | - |
| lambda-simple-lazy | normal | rune | O2 | correctness | 1/1 | 24.200000000 | 24.200000000 to 24.200000000 | - |
| lambda-simple-lazy | normal | rune | O2 | count | 1/1 | 20.500000000 | 20.500000000 to 20.500000000 | 2712266227/6342007496/199747177 |
| lambda-simple-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.410000000 | 2.410000000 to 2.410000000 | - |
| lambda-simple-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| lambda-simple-lazy | normal | rune:opt | O2 | correctness | 1/1 | 10.310000000 | 10.310000000 to 10.310000000 | - |
| lambda-simple-lazy | normal | rune:opt | O2 | count | 1/1 | 9.260000000 | 9.260000000 to 9.260000000 | 2712266227/6342007496/199747177 |
| lambda-simple-lazy | normal | rune:new | O2 | compile | 1/1 | 2.740000000 | 2.740000000 to 2.740000000 | - |
| lambda-simple-lazy | normal | rune:new | O2 | correctness | 1/1 | 19.900000000 | 19.900000000 to 19.900000000 | - |
| lambda-simple-lazy | normal | rune:new | O2 | count | 1/1 | 21.170000000 | 21.170000000 to 21.170000000 | 1574137424/6342007496/199747177 |
| lambda-simple-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.030000000 | 2.030000000 to 2.030000000 | - |
| lambda-simple-lazy | normal | rune:jit | O2 | correctness | 1/1 | 7.990000000 | 7.990000000 to 7.990000000 | - |
| lambda-simple-lazy | normal | rune:jit | O2 | count | 1/1 | 8.560000000 | 8.560000000 to 8.560000000 | 1574137424/6342007496/199747177 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

