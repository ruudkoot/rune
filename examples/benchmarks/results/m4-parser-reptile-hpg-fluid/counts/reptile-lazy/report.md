# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| reptile-lazy | normal | rune | O2 | compile | 1/1 | 4.040000000 | 4.040000000 to 4.040000000 | - |
| reptile-lazy | normal | rune | O2 | correctness | 1/1 | 62.750000000 | 62.750000000 to 62.750000000 | - |
| reptile-lazy | normal | rune | O2 | count | 1/1 | 67.990000000 | 67.990000000 to 67.990000000 | 7271729608/23643451920/712842632 |
| reptile-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.670000000 | 3.670000000 to 3.670000000 | - |
| reptile-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| reptile-lazy | normal | rune:opt | O2 | correctness | 1/1 | 34.220000000 | 34.220000000 to 34.220000000 | - |
| reptile-lazy | normal | rune:opt | O2 | count | 1/1 | 36.450000000 | 36.450000000 to 36.450000000 | 7271729608/23643451920/712842632 |
| reptile-lazy | normal | rune:new | O2 | compile | 1/1 | 4.290000000 | 4.290000000 to 4.290000000 | - |
| reptile-lazy | normal | rune:new | O2 | correctness | 1/1 | 61.900000000 | 61.900000000 to 61.900000000 | - |
| reptile-lazy | normal | rune:new | O2 | count | 1/1 | 67.630000000 | 67.630000000 to 67.630000000 | 4391743676/23643451920/712842632 |
| reptile-lazy | normal | rune:jit | O2 | compile | 1/1 | 4.570000000 | 4.570000000 to 4.570000000 | - |
| reptile-lazy | normal | rune:jit | O2 | correctness | 1/1 | 34.640000000 | 34.640000000 to 34.640000000 | - |
| reptile-lazy | normal | rune:jit | O2 | count | 1/1 | 35.080000000 | 35.080000000 to 35.080000000 | 4391743676/23643451920/712842632 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

