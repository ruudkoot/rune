# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-lazy | normal | rune | O2 | compile | 1/1 | 5.890000000 | 5.890000000 to 5.890000000 | - |
| simple-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 94.510000000 | 94.510000000 to 94.510000000 | - |
| simple-nofib-lazy | normal | rune | O2 | count | 1/1 | 59.240000000 | 59.240000000 to 59.240000000 | 7550718755/10755290528/297273470 |
| simple-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 4.080000000 | 4.080000000 to 4.080000000 | - |
| simple-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.910000000 | 0.910000000 to 0.910000000 | - |
| simple-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 28.910000000 | 28.910000000 to 28.910000000 | - |
| simple-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 27.950000000 | 27.950000000 to 27.950000000 | 7550718755/10755290528/297273470 |
| simple-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 3.360000000 | 3.360000000 to 3.360000000 | - |
| simple-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 64.340000000 | 64.340000000 to 64.340000000 | - |
| simple-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 52.760000000 | 52.760000000 to 52.760000000 | 4092090803/10755290528/297273470 |
| simple-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.980000000 | 3.980000000 to 3.980000000 | - |
| simple-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 28.340000000 | 28.340000000 to 28.340000000 | - |
| simple-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 23.460000000 | 23.460000000 to 23.460000000 | 4092090803/10755290528/297273470 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

