# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| minimax-lazy | normal | rune | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| minimax-lazy | normal | rune | O2 | correctness | 1/1 | 4.530000000 | 4.530000000 to 4.530000000 | - |
| minimax-lazy | normal | rune | O2 | count | 1/1 | 4.750000000 | 4.750000000 to 4.750000000 | 974009066/2452412368/76280196 |
| minimax-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| minimax-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| minimax-lazy | normal | rune:opt | O2 | correctness | 1/1 | 2.060000000 | 2.060000000 to 2.060000000 | - |
| minimax-lazy | normal | rune:opt | O2 | count | 1/1 | 3.830000000 | 3.830000000 to 3.830000000 | 974009066/2452412368/76280196 |
| minimax-lazy | normal | rune:new | O2 | compile | 1/1 | 1.780000000 | 1.780000000 to 1.780000000 | - |
| minimax-lazy | normal | rune:new | O2 | correctness | 1/1 | 4.190000000 | 4.190000000 to 4.190000000 | - |
| minimax-lazy | normal | rune:new | O2 | count | 1/1 | 4.110000000 | 4.110000000 to 4.110000000 | 558072978/2452412368/76280196 |
| minimax-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| minimax-lazy | normal | rune:jit | O2 | correctness | 1/1 | 1.750000000 | 1.750000000 to 1.750000000 | - |
| minimax-lazy | normal | rune:jit | O2 | count | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | 558072978/2452412368/76280196 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

