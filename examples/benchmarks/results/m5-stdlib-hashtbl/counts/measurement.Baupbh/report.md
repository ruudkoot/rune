# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| int_find1 | normal | rune | O2 | compile | 1/1 | 2.770000000 | 2.770000000 to 2.770000000 | - |
| int_find1 | normal | rune | O2 | correctness | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| int_find1 | normal | rune | O2 | count | 1/1 | 2.350000000 | 2.350000000 to 2.350000000 | 147218826/170592/2664 |
| int_find1 | normal | rune:opt | O2 | compile | 1/1 | 3.610000000 | 3.610000000 to 3.610000000 | - |
| int_find1 | normal | rune:opt | O2 | native-compile | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | - |
| int_find1 | normal | rune:opt | O2 | correctness | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | - |
| int_find1 | normal | rune:opt | O2 | count | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | 147218826/170592/2664 |
| int_find1 | normal | rune:new | O2 | compile | 1/1 | 2.730000000 | 2.730000000 to 2.730000000 | - |
| int_find1 | normal | rune:new | O2 | correctness | 1/1 | 1.050000000 | 1.050000000 to 1.050000000 | - |
| int_find1 | normal | rune:new | O2 | count | 1/1 | 1.020000000 | 1.020000000 to 1.020000000 | 111160466/170592/2664 |
| int_find1 | normal | rune:jit | O2 | compile | 1/1 | 2.930000000 | 2.930000000 to 2.930000000 | - |
| int_find1 | normal | rune:jit | O2 | correctness | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| int_find1 | normal | rune:jit | O2 | count | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | 111160466/170592/2664 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

