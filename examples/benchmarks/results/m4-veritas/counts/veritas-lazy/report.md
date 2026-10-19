# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| veritas-lazy | normal | rune | O2 | compile | 1/1 | 16.760000000 | 16.760000000 to 16.760000000 | - |
| veritas-lazy | normal | rune | O2 | correctness | 1/1 | 63.960000000 | 63.960000000 to 63.960000000 | - |
| veritas-lazy | normal | rune | O2 | count | 1/1 | 61.210000000 | 61.210000000 to 61.210000000 | 5955280603/20999088400/643799242 |
| veritas-lazy | normal | rune:opt | O2 | compile | 1/1 | 15.420000000 | 15.420000000 to 15.420000000 | - |
| veritas-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 5.520000000 | 5.520000000 to 5.520000000 | - |
| veritas-lazy | normal | rune:opt | O2 | correctness | 1/1 | 38.000000000 | 38.000000000 to 38.000000000 | - |
| veritas-lazy | normal | rune:opt | O2 | count | 1/1 | 33.360000000 | 33.360000000 to 33.360000000 | 5955280603/20999088400/643799242 |
| veritas-lazy | normal | rune:new | O2 | compile | 1/1 | 11.650000000 | 11.650000000 to 11.650000000 | - |
| veritas-lazy | normal | rune:new | O2 | correctness | 1/1 | 64.490000000 | 64.490000000 to 64.490000000 | - |
| veritas-lazy | normal | rune:new | O2 | count | 1/1 | 68.660000000 | 68.660000000 to 68.660000000 | 3573940080/20999088400/643799242 |
| veritas-lazy | normal | rune:jit | O2 | compile | 1/1 | 12.360000000 | 12.360000000 to 12.360000000 | - |
| veritas-lazy | normal | rune:jit | O2 | correctness | 1/1 | 31.240000000 | 31.240000000 to 31.240000000 | - |
| veritas-lazy | normal | rune:jit | O2 | count | 1/1 | 29.460000000 | 29.460000000 to 29.460000000 | 3573940080/20999088400/643799242 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

