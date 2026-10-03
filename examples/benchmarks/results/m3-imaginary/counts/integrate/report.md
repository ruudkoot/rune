# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| integrate-lazy | normal | rune | O2 | compile | 1/1 | 2.040000000 | 2.040000000 to 2.040000000 | - |
| integrate-lazy | normal | rune | O2 | correctness | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| integrate-lazy | normal | rune | O2 | count | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | 32025560/63725736/1761221 |
| integrate-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.080000000 | 2.080000000 to 2.080000000 | - |
| integrate-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| integrate-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| integrate-lazy | normal | rune:opt | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 32025560/63725736/1761221 |
| integrate-lazy | normal | rune:new | O2 | compile | 1/1 | 2.240000000 | 2.240000000 to 2.240000000 | - |
| integrate-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| integrate-lazy | normal | rune:new | O2 | count | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | 18965632/63725736/1761221 |
| integrate-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.340000000 | 2.340000000 to 2.340000000 | - |
| integrate-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| integrate-lazy | normal | rune:jit | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 18965632/63725736/1761221 |
| integrate-strict | normal | rune | O2 | compile | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| integrate-strict | normal | rune | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| integrate-strict | normal | rune | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 25055531/42444688/1061182 |
| integrate-strict | normal | rune:opt | O2 | compile | 1/1 | 2.220000000 | 2.220000000 to 2.220000000 | - |
| integrate-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | - |
| integrate-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| integrate-strict | normal | rune:opt | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 25055531/42444688/1061182 |
| integrate-strict | normal | rune:new | O2 | compile | 1/1 | 2.080000000 | 2.080000000 to 2.080000000 | - |
| integrate-strict | normal | rune:new | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| integrate-strict | normal | rune:new | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 14815600/42444688/1061182 |
| integrate-strict | normal | rune:jit | O2 | compile | 1/1 | 2.000000000 | 2.000000000 to 2.000000000 | - |
| integrate-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| integrate-strict | normal | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 14815600/42444688/1061182 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

