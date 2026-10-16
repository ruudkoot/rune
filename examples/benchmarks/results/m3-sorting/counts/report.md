# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| sorting-lazy | normal | rune | O2 | compile | 1/1 | 2.760000000 | 2.760000000 to 2.760000000 | - |
| sorting-lazy | normal | rune | O2 | correctness | 1/1 | 39.640000000 | 39.640000000 to 39.640000000 | - |
| sorting-lazy | normal | rune | O2 | count | 1/1 | 34.790000000 | 34.790000000 to 34.790000000 | 7142855072/11311440808/343144745 |
| sorting-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.740000000 | 1.740000000 to 1.740000000 | - |
| sorting-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| sorting-lazy | normal | rune:opt | O2 | correctness | 1/1 | 18.040000000 | 18.040000000 to 18.040000000 | - |
| sorting-lazy | normal | rune:opt | O2 | count | 1/1 | 17.870000000 | 17.870000000 to 17.870000000 | 7142855072/11311440808/343144745 |
| sorting-lazy | normal | rune:new | O2 | compile | 1/1 | 1.760000000 | 1.760000000 to 1.760000000 | - |
| sorting-lazy | normal | rune:new | O2 | correctness | 1/1 | 33.330000000 | 33.330000000 to 33.330000000 | - |
| sorting-lazy | normal | rune:new | O2 | count | 1/1 | 36.900000000 | 36.900000000 to 36.900000000 | 4031775361/11311440808/343144745 |
| sorting-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.020000000 | 3.020000000 to 3.020000000 | - |
| sorting-lazy | normal | rune:jit | O2 | correctness | 1/1 | 16.940000000 | 16.940000000 to 16.940000000 | - |
| sorting-lazy | normal | rune:jit | O2 | count | 1/1 | 15.750000000 | 15.750000000 to 15.750000000 | 4031775361/11311440808/343144745 |
| sorting-strict | normal | rune | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| sorting-strict | normal | rune | O2 | correctness | 1/1 | 8.920000000 | 8.920000000 to 8.920000000 | - |
| sorting-strict | normal | rune | O2 | count | 1/1 | 7.580000000 | 7.580000000 to 7.580000000 | 2383854896/2765765504/66622140 |
| sorting-strict | normal | rune:opt | O2 | compile | 1/1 | 1.940000000 | 1.940000000 to 1.940000000 | - |
| sorting-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| sorting-strict | normal | rune:opt | O2 | correctness | 1/1 | 3.140000000 | 3.140000000 to 3.140000000 | - |
| sorting-strict | normal | rune:opt | O2 | count | 1/1 | 3.300000000 | 3.300000000 to 3.300000000 | 2383854896/2765765504/66622140 |
| sorting-strict | normal | rune:new | O2 | compile | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |
| sorting-strict | normal | rune:new | O2 | correctness | 1/1 | 6.980000000 | 6.980000000 to 6.980000000 | - |
| sorting-strict | normal | rune:new | O2 | count | 1/1 | 8.530000000 | 8.530000000 to 8.530000000 | 1224228375/2765765504/66622140 |
| sorting-strict | normal | rune:jit | O2 | compile | 1/1 | 1.680000000 | 1.680000000 to 1.680000000 | - |
| sorting-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.420000000 | 2.420000000 to 2.420000000 | - |
| sorting-strict | normal | rune:jit | O2 | count | 1/1 | 2.520000000 | 2.520000000 to 2.520000000 | 1224228375/2765765504/66622140 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

