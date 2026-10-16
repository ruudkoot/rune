# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| integer-lazy | normal | rune | O2 | compile | 1/1 | 1.690000000 | 1.690000000 to 1.690000000 | - |
| integer-lazy | normal | rune | O2 | correctness | 1/1 | 21.540000000 | 21.540000000 to 21.540000000 | - |
| integer-lazy | normal | rune | O2 | count | 1/1 | 18.200000000 | 18.200000000 to 18.200000000 | 4576013587/7791064504/208997645 |
| integer-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.110000000 | 2.110000000 to 2.110000000 | - |
| integer-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| integer-lazy | normal | rune:opt | O2 | correctness | 1/1 | 6.700000000 | 6.700000000 to 6.700000000 | - |
| integer-lazy | normal | rune:opt | O2 | count | 1/1 | 6.690000000 | 6.690000000 to 6.690000000 | 4576013587/7791064504/208997645 |
| integer-lazy | normal | rune:new | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| integer-lazy | normal | rune:new | O2 | correctness | 1/1 | 18.120000000 | 18.120000000 to 18.120000000 | - |
| integer-lazy | normal | rune:new | O2 | count | 1/1 | 20.550000000 | 20.550000000 to 20.550000000 | 2645802621/7791064504/208997645 |
| integer-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| integer-lazy | normal | rune:jit | O2 | correctness | 1/1 | 8.120000000 | 8.120000000 to 8.120000000 | - |
| integer-lazy | normal | rune:jit | O2 | count | 1/1 | 7.970000000 | 7.970000000 to 7.970000000 | 2645802621/7791064504/208997645 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

