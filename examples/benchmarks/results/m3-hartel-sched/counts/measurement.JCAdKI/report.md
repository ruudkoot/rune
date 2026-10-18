# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| sched-lazy | normal | rune | O2 | compile | 1/1 | 2.850000000 | 2.850000000 to 2.850000000 | - |
| sched-lazy | normal | rune | O2 | correctness | 1/1 | 145.260000000 | 145.260000000 to 145.260000000 | - |
| sched-lazy | normal | rune | O2 | count | 1/1 | 148.600000000 | 148.600000000 to 148.600000000 | 14374025719/42296991584/1287478998 |
| sched-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.450000000 | 2.450000000 to 2.450000000 | - |
| sched-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | - |
| sched-lazy | normal | rune:opt | O2 | correctness | 1/1 | 62.050000000 | 62.050000000 to 62.050000000 | - |
| sched-lazy | normal | rune:opt | O2 | count | 1/1 | 61.540000000 | 61.540000000 to 61.540000000 | 14374025719/42296991584/1287478998 |
| sched-lazy | normal | rune:new | O2 | compile | 1/1 | 2.400000000 | 2.400000000 to 2.400000000 | - |
| sched-lazy | normal | rune:new | O2 | correctness | 1/1 | 136.540000000 | 136.540000000 to 136.540000000 | - |
| sched-lazy | normal | rune:new | O2 | count | 1/1 | 138.970000000 | 138.970000000 to 138.970000000 | 8616494669/42296991584/1287478998 |
| sched-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.930000000 | 1.930000000 to 1.930000000 | - |
| sched-lazy | normal | rune:jit | O2 | correctness | 1/1 | 47.310000000 | 47.310000000 to 47.310000000 | - |
| sched-lazy | normal | rune:jit | O2 | count | 1/1 | 42.360000000 | 42.360000000 to 42.360000000 | 8616494669/42296991584/1287478998 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

