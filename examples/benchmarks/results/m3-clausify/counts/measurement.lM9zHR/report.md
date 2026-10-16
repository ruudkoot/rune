# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| clausify-lazy | normal | rune | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| clausify-lazy | normal | rune | O2 | correctness | 1/1 | 50.110000000 | 50.110000000 to 50.110000000 | - |
| clausify-lazy | normal | rune | O2 | count | 1/1 | 46.240000000 | 46.240000000 to 46.240000000 | 9736845055/23679833296/775763082 |
| clausify-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | - |
| clausify-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| clausify-lazy | normal | rune:opt | O2 | correctness | 1/1 | 24.250000000 | 24.250000000 to 24.250000000 | - |
| clausify-lazy | normal | rune:opt | O2 | count | 1/1 | 25.140000000 | 25.140000000 to 25.140000000 | 9736845055/23679833296/775763082 |
| clausify-lazy | normal | rune:new | O2 | compile | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| clausify-lazy | normal | rune:new | O2 | correctness | 1/1 | 44.620000000 | 44.620000000 to 44.620000000 | - |
| clausify-lazy | normal | rune:new | O2 | count | 1/1 | 45.010000000 | 45.010000000 to 45.010000000 | 5536679167/23679833296/775763082 |
| clausify-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| clausify-lazy | normal | rune:jit | O2 | correctness | 1/1 | 23.240000000 | 23.240000000 to 23.240000000 | - |
| clausify-lazy | normal | rune:jit | O2 | count | 1/1 | 22.660000000 | 22.660000000 to 22.660000000 | 5536679167/23679833296/775763082 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

