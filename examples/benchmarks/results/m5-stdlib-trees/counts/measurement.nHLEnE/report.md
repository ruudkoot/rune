# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| map_for_all | normal | rune | O2 | compile | 1/1 | 4.930000000 | 4.930000000 to 4.930000000 | - |
| map_for_all | normal | rune | O2 | correctness | 1/1 | 5.030000000 | 5.030000000 to 5.030000000 | - |
| map_for_all | normal | rune | O2 | count | 1/1 | 4.040000000 | 4.040000000 to 4.040000000 | 417687836/417805552/10318702 |
| map_for_all | normal | rune:opt | O2 | compile | 1/1 | 3.950000000 | 3.950000000 to 3.950000000 | - |
| map_for_all | normal | rune:opt | O2 | native-compile | 1/1 | 1.740000000 | 1.740000000 to 1.740000000 | - |
| map_for_all | normal | rune:opt | O2 | correctness | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| map_for_all | normal | rune:opt | O2 | count | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | 417687836/417805552/10318702 |
| map_for_all | normal | rune:new | O2 | compile | 1/1 | 3.610000000 | 3.610000000 to 3.610000000 | - |
| map_for_all | normal | rune:new | O2 | correctness | 1/1 | 4.050000000 | 4.050000000 to 4.050000000 | - |
| map_for_all | normal | rune:new | O2 | count | 1/1 | 4.010000000 | 4.010000000 to 4.010000000 | 249201229/417805552/10318702 |
| map_for_all | normal | rune:jit | O2 | compile | 1/1 | 3.200000000 | 3.200000000 to 3.200000000 | - |
| map_for_all | normal | rune:jit | O2 | correctness | 1/1 | 1.580000000 | 1.580000000 to 1.580000000 | - |
| map_for_all | normal | rune:jit | O2 | count | 1/1 | 1.710000000 | 1.710000000 to 1.710000000 | 249201229/417805552/10318702 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

