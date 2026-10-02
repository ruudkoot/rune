# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| tak-nofib-strict | normal | rune | O2 | compile | 1/1 | 2.360000000 | 2.360000000 to 2.360000000 | - |
| tak-nofib-strict | normal | rune | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| tak-nofib-strict | normal | rune | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 710660/19968/524 |
| tak-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 2.260000000 | 2.260000000 to 2.260000000 | - |
| tak-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| tak-nofib-strict | normal | rune:new | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 388287/19968/524 |
| tak-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 2.660000000 | 2.660000000 to 2.660000000 | - |
| tak-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| tak-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 388287/19968/524 |
| tak-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 2.790000000 | 2.790000000 to 2.790000000 | - |
| tak-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.780000000 | 0.780000000 to 0.780000000 | - |
| tak-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| tak-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 710660/19968/524 |
| tak-nofib-lazy | normal | rune | O2 | compile | 1/1 | 2.460000000 | 2.460000000 to 2.460000000 | - |
| tak-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| tak-nofib-lazy | normal | rune | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 4956562/12233024/382186 |
| tak-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 2.220000000 | 2.220000000 to 2.220000000 | - |
| tak-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| tak-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 3043960/12233024/382186 |
| tak-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.310000000 | 2.310000000 to 2.310000000 | - |
| tak-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| tak-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 3043960/12233024/382186 |
| tak-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.460000000 | 2.460000000 to 2.460000000 | - |
| tak-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.700000000 | 0.700000000 to 0.700000000 | - |
| tak-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| tak-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 4956562/12233024/382186 |
|  | normal | rune:opt | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

