# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| multiplier-lazy | normal | rune | O2 | compile | 1/1 | 1.740000000 | 1.740000000 to 1.740000000 | - |
| multiplier-lazy | normal | rune | O2 | correctness | 1/1 | 39.120000000 | 39.120000000 to 39.120000000 | - |
| multiplier-lazy | normal | rune | O2 | count | 1/1 | 40.170000000 | 40.170000000 to 40.170000000 | 4807849598/12841520000/374553042 |
| multiplier-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.700000000 | 1.700000000 to 1.700000000 | - |
| multiplier-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| multiplier-lazy | normal | rune:opt | O2 | correctness | 1/1 | 20.340000000 | 20.340000000 to 20.340000000 | - |
| multiplier-lazy | normal | rune:opt | O2 | count | 1/1 | 20.830000000 | 20.830000000 to 20.830000000 | 4807849598/12841520000/374553042 |
| multiplier-lazy | normal | rune:new | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| multiplier-lazy | normal | rune:new | O2 | correctness | 1/1 | 36.850000000 | 36.850000000 to 36.850000000 | - |
| multiplier-lazy | normal | rune:new | O2 | count | 1/1 | 37.250000000 | 37.250000000 to 37.250000000 | 2876574838/12841520000/374553042 |
| multiplier-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.350000000 | 2.350000000 to 2.350000000 | - |
| multiplier-lazy | normal | rune:jit | O2 | correctness | 1/1 | 25.580000000 | 25.580000000 to 25.580000000 | - |
| multiplier-lazy | normal | rune:jit | O2 | count | 1/1 | 27.560000000 | 27.560000000 to 27.560000000 | 2876574838/12841520000/374553042 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

