# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| transform-strict | normal | rune | O2 | compile | 1/1 | 3.680000000 | 3.680000000 to 3.680000000 | - |
| transform-strict | normal | rune | O2 | correctness | 1/1 | 15.520000000 | 15.520000000 to 15.520000000 | - |
| transform-strict | normal | rune | O2 | count | 1/1 | 14.320000000 | 14.320000000 to 14.320000000 | 2049196753/4070447736/102108895 |
| transform-strict | normal | rune:opt | O2 | compile | 1/1 | 3.310000000 | 3.310000000 to 3.310000000 | - |
| transform-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.900000000 | 0.900000000 to 0.900000000 | - |
| transform-strict | normal | rune:opt | O2 | correctness | 1/1 | 6.020000000 | 6.020000000 to 6.020000000 | - |
| transform-strict | normal | rune:opt | O2 | count | 1/1 | 6.930000000 | 6.930000000 to 6.930000000 | 2049196753/4070447736/102108895 |
| transform-strict | normal | rune:new | O2 | compile | 1/1 | 3.620000000 | 3.620000000 to 3.620000000 | - |
| transform-strict | normal | rune:new | O2 | correctness | 1/1 | 13.170000000 | 13.170000000 to 13.170000000 | - |
| transform-strict | normal | rune:new | O2 | count | 1/1 | 16.470000000 | 16.470000000 to 16.470000000 | 1160579837/4070447736/102108895 |
| transform-strict | normal | rune:jit | O2 | compile | 1/1 | 4.250000000 | 4.250000000 to 4.250000000 | - |
| transform-strict | normal | rune:jit | O2 | correctness | 1/1 | 6.720000000 | 6.720000000 to 6.720000000 | - |
| transform-strict | normal | rune:jit | O2 | count | 1/1 | 6.010000000 | 6.010000000 to 6.010000000 | 1160579837/4070447736/102108895 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

