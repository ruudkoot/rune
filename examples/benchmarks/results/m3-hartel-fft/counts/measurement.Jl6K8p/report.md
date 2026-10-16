# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| genfft-lazy | normal | rune | O2 | compile | 1/1 | 1.400000000 | 1.400000000 to 1.400000000 | - |
| genfft-lazy | normal | rune | O2 | correctness | 1/1 | 48.340000000 | 48.340000000 to 48.340000000 | - |
| genfft-lazy | normal | rune | O2 | count | 1/1 | 48.290000000 | 48.290000000 to 48.290000000 | 10280340094/35799351856/1086725228 |
| genfft-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| genfft-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| genfft-lazy | normal | rune:opt | O2 | correctness | 1/1 | 24.790000000 | 24.790000000 to 24.790000000 | - |
| genfft-lazy | normal | rune:opt | O2 | count | 1/1 | 22.570000000 | 22.570000000 to 22.570000000 | 10280340094/35799351856/1086725228 |
| genfft-lazy | normal | rune:new | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| genfft-lazy | normal | rune:new | O2 | correctness | 1/1 | 56.040000000 | 56.040000000 to 56.040000000 | - |
| genfft-lazy | normal | rune:new | O2 | count | 1/1 | 56.340000000 | 56.340000000 to 56.340000000 | 6310805073/35799351856/1086725228 |
| genfft-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| genfft-lazy | normal | rune:jit | O2 | correctness | 1/1 | 29.010000000 | 29.010000000 to 29.010000000 | - |
| genfft-lazy | normal | rune:jit | O2 | count | 1/1 | 25.790000000 | 25.790000000 to 25.790000000 | 6310805073/35799351856/1086725228 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

