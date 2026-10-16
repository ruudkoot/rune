# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| compress2-lazy | normal | rune | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| compress2-lazy | normal | rune | O2 | correctness | 1/1 | 41.290000000 | 41.290000000 to 41.290000000 | - |
| compress2-lazy | normal | rune | O2 | count | 1/1 | 41.660000000 | 41.660000000 to 41.660000000 | 7303515710/26809199704/699475277 |
| compress2-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.560000000 | 1.560000000 to 1.560000000 | - |
| compress2-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| compress2-lazy | normal | rune:opt | O2 | correctness | 1/1 | 23.310000000 | 23.310000000 to 23.310000000 | - |
| compress2-lazy | normal | rune:opt | O2 | count | 1/1 | 21.450000000 | 21.450000000 to 21.450000000 | 7303515710/26809199704/699475277 |
| compress2-lazy | normal | rune:new | O2 | compile | 1/1 | 1.580000000 | 1.580000000 to 1.580000000 | - |
| compress2-lazy | normal | rune:new | O2 | correctness | 1/1 | 40.370000000 | 40.370000000 to 40.370000000 | - |
| compress2-lazy | normal | rune:new | O2 | count | 1/1 | 40.140000000 | 40.140000000 to 40.140000000 | 4352628211/26809199704/699475277 |
| compress2-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | - |
| compress2-lazy | normal | rune:jit | O2 | correctness | 1/1 | 23.180000000 | 23.180000000 to 23.180000000 | - |
| compress2-lazy | normal | rune:jit | O2 | count | 1/1 | 22.020000000 | 22.020000000 to 22.020000000 | 4352628211/26809199704/699475277 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

