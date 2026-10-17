# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| minimax-strict | normal | rune | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| minimax-strict | normal | rune | O2 | correctness | 1/1 | 32.070000000 | 32.070000000 to 32.070000000 | - |
| minimax-strict | normal | rune | O2 | count | 1/1 | 32.110000000 | 32.110000000 to 32.110000000 | 9004111933/13190403584/318934258 |
| minimax-strict | normal | rune:opt | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| minimax-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| minimax-strict | normal | rune:opt | O2 | correctness | 1/1 | 12.180000000 | 12.180000000 to 12.180000000 | - |
| minimax-strict | normal | rune:opt | O2 | count | 1/1 | 14.300000000 | 14.300000000 to 14.300000000 | 9004111933/13190403584/318934258 |
| minimax-strict | normal | rune:new | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| minimax-strict | normal | rune:new | O2 | correctness | 1/1 | 26.830000000 | 26.830000000 to 26.830000000 | - |
| minimax-strict | normal | rune:new | O2 | count | 1/1 | 24.740000000 | 24.740000000 to 24.740000000 | 4568468328/13190403584/318934258 |
| minimax-strict | normal | rune:jit | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| minimax-strict | normal | rune:jit | O2 | correctness | 1/1 | 11.600000000 | 11.600000000 to 11.600000000 | - |
| minimax-strict | normal | rune:jit | O2 | count | 1/1 | 9.350000000 | 9.350000000 to 9.350000000 | 4568468328/13190403584/318934258 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

