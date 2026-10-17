# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| expert-lazy | normal | rune | O2 | compile | 1/1 | 2.280000000 | 2.280000000 to 2.280000000 | - |
| expert-lazy | normal | rune | O2 | correctness | 1/1 | 18.440000000 | 18.440000000 to 18.440000000 | - |
| expert-lazy | normal | rune | O2 | count | 1/1 | 15.480000000 | 15.480000000 to 15.480000000 | 2484829442/7033173280/219821408 |
| expert-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.780000000 | 1.780000000 to 1.780000000 | - |
| expert-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | - |
| expert-lazy | normal | rune:opt | O2 | correctness | 1/1 | 7.050000000 | 7.050000000 to 7.050000000 | - |
| expert-lazy | normal | rune:opt | O2 | count | 1/1 | 6.920000000 | 6.920000000 to 6.920000000 | 2484829442/7033173280/219821408 |
| expert-lazy | normal | rune:new | O2 | compile | 1/1 | 1.770000000 | 1.770000000 to 1.770000000 | - |
| expert-lazy | normal | rune:new | O2 | correctness | 1/1 | 15.520000000 | 15.520000000 to 15.520000000 | - |
| expert-lazy | normal | rune:new | O2 | count | 1/1 | 17.430000000 | 17.430000000 to 17.430000000 | 1479531795/7033173280/219821408 |
| expert-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.010000000 | 2.010000000 to 2.010000000 | - |
| expert-lazy | normal | rune:jit | O2 | correctness | 1/1 | 6.680000000 | 6.680000000 to 6.680000000 | - |
| expert-lazy | normal | rune:jit | O2 | count | 1/1 | 6.670000000 | 6.670000000 to 6.670000000 | 1479531795/7033173280/219821408 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

