# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lcss-lazy | normal | rune | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| lcss-lazy | normal | rune | O2 | correctness | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| lcss-lazy | normal | rune | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 19665274/71170472/1860431 |
| lcss-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| lcss-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| lcss-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| lcss-lazy | normal | rune:opt | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 19665274/71170472/1860431 |
| lcss-lazy | normal | rune:new | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| lcss-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| lcss-lazy | normal | rune:new | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 10985576/71170472/1860431 |
| lcss-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| lcss-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| lcss-lazy | normal | rune:jit | O2 | count | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | 10985576/71170472/1860431 |
| lcss-strict | normal | rune | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| lcss-strict | normal | rune | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| lcss-strict | normal | rune | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 4993649/10774760/269377 |
| lcss-strict | normal | rune:opt | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| lcss-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| lcss-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| lcss-strict | normal | rune:opt | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 4993649/10774760/269377 |
| lcss-strict | normal | rune:new | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| lcss-strict | normal | rune:new | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| lcss-strict | normal | rune:new | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 1989887/10774760/269377 |
| lcss-strict | normal | rune:jit | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| lcss-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| lcss-strict | normal | rune:jit | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 1989887/10774760/269377 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

