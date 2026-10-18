# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| sched-strict | normal | rune | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| sched-strict | normal | rune | O2 | correctness | 1/1 | 21.400000000 | 21.400000000 to 21.400000000 | - |
| sched-strict | normal | rune | O2 | count | 1/1 | 18.600000000 | 18.600000000 to 18.600000000 | 3614150835/9479372688/195788206 |
| sched-strict | normal | rune:opt | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| sched-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| sched-strict | normal | rune:opt | O2 | correctness | 1/1 | 6.710000000 | 6.710000000 to 6.710000000 | - |
| sched-strict | normal | rune:opt | O2 | count | 1/1 | 8.010000000 | 8.010000000 to 8.010000000 | 3614150835/9479372688/195788206 |
| sched-strict | normal | rune:new | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| sched-strict | normal | rune:new | O2 | correctness | 1/1 | 17.250000000 | 17.250000000 to 17.250000000 | - |
| sched-strict | normal | rune:new | O2 | count | 1/1 | 18.780000000 | 18.780000000 to 18.780000000 | 2179445139/9479372688/195788206 |
| sched-strict | normal | rune:jit | O2 | compile | 1/1 | 1.660000000 | 1.660000000 to 1.660000000 | - |
| sched-strict | normal | rune:jit | O2 | correctness | 1/1 | 7.990000000 | 7.990000000 to 7.990000000 | - |
| sched-strict | normal | rune:jit | O2 | count | 1/1 | 7.620000000 | 7.620000000 to 7.620000000 | 2179445139/9479372688/195788206 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

