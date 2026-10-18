# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| solid-lazy | normal | rune | O2 | compile | 1/1 | 2.820000000 | 2.820000000 to 2.820000000 | - |
| solid-lazy | normal | rune | O2 | correctness | 1/1 | 105.680000000 | 105.680000000 to 105.680000000 | - |
| solid-lazy | normal | rune | O2 | count | 1/1 | 98.560000000 | 98.560000000 to 98.560000000 | 10533453905/22166946272/679183104 |
| solid-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| solid-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.630000000 | 0.630000000 to 0.630000000 | - |
| solid-lazy | normal | rune:opt | O2 | correctness | 1/1 | 48.240000000 | 48.240000000 to 48.240000000 | - |
| solid-lazy | normal | rune:opt | O2 | count | 1/1 | 52.440000000 | 52.440000000 to 52.440000000 | 10533453905/22166946272/679183104 |
| solid-lazy | normal | rune:new | O2 | compile | 1/1 | 6.760000000 | 6.760000000 to 6.760000000 | - |
| solid-lazy | normal | rune:new | O2 | correctness | 1/1 | 107.580000000 | 107.580000000 to 107.580000000 | - |
| solid-lazy | normal | rune:new | O2 | count | 1/1 | 114.480000000 | 114.480000000 to 114.480000000 | 5900752808/22166946272/679183104 |
| solid-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.560000000 | 2.560000000 to 2.560000000 | - |
| solid-lazy | normal | rune:jit | O2 | correctness | 1/1 | 38.010000000 | 38.010000000 to 38.010000000 | - |
| solid-lazy | normal | rune:jit | O2 | count | 1/1 | 36.350000000 | 36.350000000 to 36.350000000 | 5900752808/22166946272/679183104 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

