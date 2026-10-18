# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| map_map | normal | rune | O2 | compile | 1/1 | 3.340000000 | 3.340000000 to 3.340000000 | - |
| map_map | normal | rune | O2 | correctness | 1/1 | 16.380000000 | 16.380000000 to 16.380000000 | - |
| map_map | normal | rune | O2 | count | 1/1 | 16.370000000 | 16.370000000 to 16.370000000 | 1337692853/2417845496/40319701 |
| map_map | normal | rune:opt | O2 | compile | 1/1 | 6.860000000 | 6.860000000 to 6.860000000 | - |
| map_map | normal | rune:opt | O2 | native-compile | 1/1 | 0.890000000 | 0.890000000 to 0.890000000 | - |
| map_map | normal | rune:opt | O2 | correctness | 1/1 | 8.880000000 | 8.880000000 to 8.880000000 | - |
| map_map | normal | rune:opt | O2 | count | 1/1 | 8.070000000 | 8.070000000 to 8.070000000 | 1337692853/2417845496/40319701 |
| map_map | normal | rune:new | O2 | compile | 1/1 | 5.630000000 | 5.630000000 to 5.630000000 | - |
| map_map | normal | rune:new | O2 | correctness | 1/1 | 19.850000000 | 19.850000000 to 19.850000000 | - |
| map_map | normal | rune:new | O2 | count | 1/1 | 21.800000000 | 21.800000000 to 21.800000000 | 799201244/2417845496/40319701 |
| map_map | normal | rune:jit | O2 | compile | 1/1 | 5.020000000 | 5.020000000 to 5.020000000 | - |
| map_map | normal | rune:jit | O2 | correctness | 1/1 | 7.630000000 | 7.630000000 to 7.630000000 | - |
| map_map | normal | rune:jit | O2 | count | 1/1 | 7.340000000 | 7.340000000 to 7.340000000 | 799201244/2417845496/40319701 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

