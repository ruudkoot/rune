# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| map_find | normal | rune | O2 | compile | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| map_find | normal | rune | O2 | correctness | 1/1 | 4.080000000 | 4.080000000 to 4.080000000 | - |
| map_find | normal | rune | O2 | count | 1/1 | 5.250000000 | 5.250000000 to 5.250000000 | 608737331/18021816/327711 |
| map_find | normal | rune:opt | O2 | compile | 1/1 | 2.630000000 | 2.630000000 to 2.630000000 | - |
| map_find | normal | rune:opt | O2 | native-compile | 1/1 | 0.690000000 | 0.690000000 to 0.690000000 | - |
| map_find | normal | rune:opt | O2 | correctness | 1/1 | 1.120000000 | 1.120000000 to 1.120000000 | - |
| map_find | normal | rune:opt | O2 | count | 1/1 | 1.050000000 | 1.050000000 to 1.050000000 | 608737331/18021816/327711 |
| map_find | normal | rune:new | O2 | compile | 1/1 | 2.780000000 | 2.780000000 to 2.780000000 | - |
| map_find | normal | rune:new | O2 | correctness | 1/1 | 2.890000000 | 2.890000000 to 2.890000000 | - |
| map_find | normal | rune:new | O2 | count | 1/1 | 3.370000000 | 3.370000000 to 3.370000000 | 345599132/18021816/327711 |
| map_find | normal | rune:jit | O2 | compile | 1/1 | 4.340000000 | 4.340000000 to 4.340000000 | - |
| map_find | normal | rune:jit | O2 | correctness | 1/1 | 0.900000000 | 0.900000000 to 0.900000000 | - |
| map_find | normal | rune:jit | O2 | count | 1/1 | 1.030000000 | 1.030000000 to 1.030000000 | 345599132/18021816/327711 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

