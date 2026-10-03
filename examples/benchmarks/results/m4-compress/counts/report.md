# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| compress-lazy | normal | rune | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| compress-lazy | normal | rune | O2 | correctness | 1/1 | 10.040000000 | 10.040000000 to 10.040000000 | - |
| compress-lazy | normal | rune | O2 | count | 1/1 | 10.660000000 | 10.660000000 to 10.660000000 | 2053384980/6496245408/152467444 |
| compress-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| compress-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| compress-lazy | normal | rune:opt | O2 | correctness | 1/1 | 4.200000000 | 4.200000000 to 4.200000000 | - |
| compress-lazy | normal | rune:opt | O2 | count | 1/1 | 4.340000000 | 4.340000000 to 4.340000000 | 2053384980/6496245408/152467444 |
| compress-lazy | normal | rune:new | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| compress-lazy | normal | rune:new | O2 | correctness | 1/1 | 8.170000000 | 8.170000000 to 8.170000000 | - |
| compress-lazy | normal | rune:new | O2 | count | 1/1 | 7.850000000 | 7.850000000 to 7.850000000 | 1164037048/6496245408/152467444 |
| compress-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.550000000 | 1.550000000 to 1.550000000 | - |
| compress-lazy | normal | rune:jit | O2 | correctness | 1/1 | 4.160000000 | 4.160000000 to 4.160000000 | - |
| compress-lazy | normal | rune:jit | O2 | count | 1/1 | 4.010000000 | 4.010000000 to 4.010000000 | 1164037048/6496245408/152467444 |
| compress-strict | normal | rune | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| compress-strict | normal | rune | O2 | correctness | 1/1 | 2.250000000 | 2.250000000 to 2.250000000 | - |
| compress-strict | normal | rune | O2 | count | 1/1 | 2.310000000 | 2.310000000 to 2.310000000 | 766105509/1677209280/30181572 |
| compress-strict | normal | rune:opt | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| compress-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| compress-strict | normal | rune:opt | O2 | correctness | 1/1 | 1.010000000 | 1.010000000 to 1.010000000 | - |
| compress-strict | normal | rune:opt | O2 | count | 1/1 | 1.050000000 | 1.050000000 to 1.050000000 | 766105509/1677209280/30181572 |
| compress-strict | normal | rune:new | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| compress-strict | normal | rune:new | O2 | correctness | 1/1 | 2.630000000 | 2.630000000 to 2.630000000 | - |
| compress-strict | normal | rune:new | O2 | count | 1/1 | 2.150000000 | 2.150000000 to 2.150000000 | 298683885/1677209280/30181572 |
| compress-strict | normal | rune:jit | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| compress-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.850000000 | 0.850000000 to 0.850000000 | - |
| compress-strict | normal | rune:jit | O2 | count | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | 298683885/1677209280/30181572 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

