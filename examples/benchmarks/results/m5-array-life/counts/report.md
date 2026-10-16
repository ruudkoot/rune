# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| game_of_life | normal | rune | O2 | compile | 1/1 | 1.840000000 | 1.840000000 to 1.840000000 | - |
| game_of_life | normal | rune | O2 | correctness | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| game_of_life | normal | rune | O2 | count | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | 204844347/6655336/129467 |
| game_of_life | normal | rune:opt | O2 | compile | 1/1 | 1.870000000 | 1.870000000 to 1.870000000 | - |
| game_of_life | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| game_of_life | normal | rune:opt | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| game_of_life | normal | rune:opt | O2 | count | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | 204844347/6655336/129467 |
| game_of_life | normal | rune:new | O2 | compile | 1/1 | 2.050000000 | 2.050000000 to 2.050000000 | - |
| game_of_life | normal | rune:new | O2 | correctness | 1/1 | 0.980000000 | 0.980000000 to 0.980000000 | - |
| game_of_life | normal | rune:new | O2 | count | 1/1 | 0.990000000 | 0.990000000 to 0.990000000 | 132430887/6655336/129467 |
| game_of_life | normal | rune:jit | O2 | compile | 1/1 | 1.650000000 | 1.650000000 to 1.650000000 | - |
| game_of_life | normal | rune:jit | O2 | correctness | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| game_of_life | normal | rune:jit | O2 | count | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | 132430887/6655336/129467 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

