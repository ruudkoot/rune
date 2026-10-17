# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gg-pool-strict | normal | rune | O2 | compile | 1/1 | 2.190000000 | 2.190000000 to 2.190000000 | - |
| gg-pool-strict | normal | rune | O2 | correctness | 1/1 | 31.960000000 | 31.960000000 to 31.960000000 | - |
| gg-pool-strict | normal | rune | O2 | count | 1/1 | 35.230000000 | 35.230000000 to 35.230000000 | 6525751361/14417625072/416782184 |
| gg-pool-strict | normal | rune:opt | O2 | compile | 1/1 | 2.570000000 | 2.570000000 to 2.570000000 | - |
| gg-pool-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | - |
| gg-pool-strict | normal | rune:opt | O2 | correctness | 1/1 | 16.450000000 | 16.450000000 to 16.450000000 | - |
| gg-pool-strict | normal | rune:opt | O2 | count | 1/1 | 16.280000000 | 16.280000000 to 16.280000000 | 6525751361/14417625072/416782184 |
| gg-pool-strict | normal | rune:new | O2 | compile | 1/1 | 2.540000000 | 2.540000000 to 2.540000000 | - |
| gg-pool-strict | normal | rune:new | O2 | correctness | 1/1 | 31.180000000 | 31.180000000 to 31.180000000 | - |
| gg-pool-strict | normal | rune:new | O2 | count | 1/1 | 33.820000000 | 33.820000000 to 33.820000000 | 3748652197/14417625072/416782184 |
| gg-pool-strict | normal | rune:jit | O2 | compile | 1/1 | 2.780000000 | 2.780000000 to 2.780000000 | - |
| gg-pool-strict | normal | rune:jit | O2 | correctness | 1/1 | 17.720000000 | 17.720000000 to 17.720000000 | - |
| gg-pool-strict | normal | rune:jit | O2 | count | 1/1 | 15.110000000 | 15.110000000 to 15.110000000 | 3748652197/14417625072/416782184 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

