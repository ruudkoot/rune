# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| grep-lazy | normal | rune | O2 | compile | 1/1 | 4.080000000 | 4.080000000 to 4.080000000 | - |
| grep-lazy | normal | rune | O2 | correctness | 1/1 | 58.360000000 | 58.360000000 to 58.360000000 | - |
| grep-lazy | normal | rune | O2 | count | 1/1 | 64.120000000 | 64.120000000 to 64.120000000 | 6832663401/19124721512/575685997 |
| grep-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.980000000 | 3.980000000 to 3.980000000 | - |
| grep-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.820000000 | 0.820000000 to 0.820000000 | - |
| grep-lazy | normal | rune:opt | O2 | correctness | 1/1 | 30.750000000 | 30.750000000 to 30.750000000 | - |
| grep-lazy | normal | rune:opt | O2 | count | 1/1 | 29.460000000 | 29.460000000 to 29.460000000 | 6832663401/19124721512/575685997 |
| grep-lazy | normal | rune:new | O2 | compile | 1/1 | 2.740000000 | 2.740000000 to 2.740000000 | - |
| grep-lazy | normal | rune:new | O2 | correctness | 1/1 | 44.650000000 | 44.650000000 to 44.650000000 | - |
| grep-lazy | normal | rune:new | O2 | count | 1/1 | 55.040000000 | 55.040000000 to 55.040000000 | 3951091085/19124721512/575685997 |
| grep-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.740000000 | 3.740000000 to 3.740000000 | - |
| grep-lazy | normal | rune:jit | O2 | correctness | 1/1 | 28.020000000 | 28.020000000 to 28.020000000 | - |
| grep-lazy | normal | rune:jit | O2 | count | 1/1 | 30.980000000 | 30.980000000 to 30.980000000 | 3951091085/19124721512/575685997 |
| grep-strict | normal | rune | O2 | compile | 1/1 | 2.880000000 | 2.880000000 to 2.880000000 | - |
| grep-strict | normal | rune | O2 | correctness | 1/1 | 21.330000000 | 21.330000000 to 21.330000000 | - |
| grep-strict | normal | rune | O2 | count | 1/1 | 19.370000000 | 19.370000000 to 19.370000000 | 3020799829/3801316664/96033395 |
| grep-strict | normal | rune:opt | O2 | compile | 1/1 | 2.580000000 | 2.580000000 to 2.580000000 | - |
| grep-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | - |
| grep-strict | normal | rune:opt | O2 | correctness | 1/1 | 7.650000000 | 7.650000000 to 7.650000000 | - |
| grep-strict | normal | rune:opt | O2 | count | 1/1 | 8.650000000 | 8.650000000 to 8.650000000 | 3020799829/3801316664/96033395 |
| grep-strict | normal | rune:new | O2 | compile | 1/1 | 2.570000000 | 2.570000000 to 2.570000000 | - |
| grep-strict | normal | rune:new | O2 | correctness | 1/1 | 13.380000000 | 13.380000000 to 13.380000000 | - |
| grep-strict | normal | rune:new | O2 | count | 1/1 | 11.550000000 | 11.550000000 to 11.550000000 | 1596560903/3801316664/96033395 |
| grep-strict | normal | rune:jit | O2 | compile | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| grep-strict | normal | rune:jit | O2 | correctness | 1/1 | 4.850000000 | 4.850000000 to 4.850000000 | - |
| grep-strict | normal | rune:jit | O2 | count | 1/1 | 5.430000000 | 5.430000000 to 5.430000000 | 1596560903/3801316664/96033395 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

