# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| map_remove | normal | rune | O2 | compile | 1/1 | 7.290000000 | 7.290000000 to 7.290000000 | - |
| map_remove | normal | rune | O2 | correctness | 1/1 | 9.710000000 | 9.710000000 to 9.710000000 | - |
| map_remove | normal | rune | O2 | count | 1/1 | 8.950000000 | 8.950000000 to 8.950000000 | 737592187/59302976/1347732 |
| map_remove | normal | rune:opt | O2 | compile | 1/1 | 4.270000000 | 4.270000000 to 4.270000000 | - |
| map_remove | normal | rune:opt | O2 | native-compile | 1/1 | 1.950000000 | 1.950000000 to 1.950000000 | - |
| map_remove | normal | rune:opt | O2 | correctness | 1/1 | 3.210000000 | 3.210000000 to 3.210000000 | - |
| map_remove | normal | rune:opt | O2 | count | 1/1 | 2.780000000 | 2.780000000 to 2.780000000 | 737592187/59302976/1347732 |
| map_remove | normal | rune:new | O2 | compile | 1/1 | 3.690000000 | 3.690000000 to 3.690000000 | - |
| map_remove | normal | rune:new | O2 | correctness | 1/1 | 4.470000000 | 4.470000000 to 4.470000000 | - |
| map_remove | normal | rune:new | O2 | count | 1/1 | 5.680000000 | 5.680000000 to 5.680000000 | 358756999/59302976/1347732 |
| map_remove | normal | rune:jit | O2 | compile | 1/1 | 5.060000000 | 5.060000000 to 5.060000000 | - |
| map_remove | normal | rune:jit | O2 | correctness | 1/1 | 1.910000000 | 1.910000000 to 1.910000000 | - |
| map_remove | normal | rune:jit | O2 | count | 1/1 | 1.560000000 | 1.560000000 to 1.560000000 | 358756999/59302976/1347732 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

