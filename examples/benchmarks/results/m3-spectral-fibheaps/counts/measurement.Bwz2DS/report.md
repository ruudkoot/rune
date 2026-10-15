# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fibheaps-nofib-lazy | normal | rune | O2 | compile | 1/1 | 2.050000000 | 2.050000000 to 2.050000000 | - |
| fibheaps-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 92.210000000 | 92.210000000 to 92.210000000 | - |
| fibheaps-nofib-lazy | normal | rune | O2 | count | 1/1 | 88.850000000 | 88.850000000 to 88.850000000 | 9760804329/29628179152/899603470 |
| fibheaps-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.090000000 | 2.090000000 to 2.090000000 | - |
| fibheaps-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| fibheaps-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 45.160000000 | 45.160000000 to 45.160000000 | - |
| fibheaps-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 44.600000000 | 44.600000000 to 44.600000000 | 9760804329/29628179152/899603470 |
| fibheaps-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| fibheaps-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 97.240000000 | 97.240000000 to 97.240000000 | - |
| fibheaps-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 98.630000000 | 98.630000000 to 98.630000000 | 5734582154/29628179152/899603470 |
| fibheaps-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.530000000 | 3.530000000 to 3.530000000 | - |
| fibheaps-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 47.740000000 | 47.740000000 to 47.740000000 | - |
| fibheaps-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 50.430000000 | 50.430000000 to 50.430000000 | 5734582154/29628179152/899603470 |
| fibheaps-nofib-strict | normal | rune | O2 | compile | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | - |
| fibheaps-nofib-strict | normal | rune | O2 | correctness | 1/1 | 21.550000000 | 21.550000000 to 21.550000000 | - |
| fibheaps-nofib-strict | normal | rune | O2 | count | 1/1 | 21.450000000 | 21.450000000 to 21.450000000 | 2624784759/5278907088/128787668 |
| fibheaps-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 2.020000000 | 2.020000000 to 2.020000000 | - |
| fibheaps-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| fibheaps-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 10.240000000 | 10.240000000 to 10.240000000 | - |
| fibheaps-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 9.100000000 | 9.100000000 to 9.100000000 | 2624784759/5278907088/128787668 |
| fibheaps-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| fibheaps-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 16.880000000 | 16.880000000 to 16.880000000 | - |
| fibheaps-nofib-strict | normal | rune:new | O2 | count | 1/1 | 18.580000000 | 18.580000000 to 18.580000000 | 1336816974/5278907088/128787668 |
| fibheaps-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 2.080000000 | 2.080000000 to 2.080000000 | - |
| fibheaps-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 8.960000000 | 8.960000000 to 8.960000000 | - |
| fibheaps-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 7.730000000 | 7.730000000 to 7.730000000 | 1336816974/5278907088/128787668 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

