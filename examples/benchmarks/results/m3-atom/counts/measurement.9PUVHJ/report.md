# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| atom-strict | normal | rune | O2 | compile | 1/1 | 1.400000000 | 1.400000000 to 1.400000000 | - |
| atom-strict | normal | rune | O2 | correctness | 1/1 | 11.400000000 | 11.400000000 to 11.400000000 | - |
| atom-strict | normal | rune | O2 | count | 1/1 | 9.780000000 | 9.780000000 to 9.780000000 | 2300263536/2847408344/78736141 |
| atom-strict | normal | rune:opt | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| atom-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| atom-strict | normal | rune:opt | O2 | correctness | 1/1 | 4.620000000 | 4.620000000 to 4.620000000 | - |
| atom-strict | normal | rune:opt | O2 | count | 1/1 | 4.750000000 | 4.750000000 to 4.750000000 | 2300263536/2847408344/78736141 |
| atom-strict | normal | rune:new | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| atom-strict | normal | rune:new | O2 | correctness | 1/1 | 11.970000000 | 11.970000000 to 11.970000000 | - |
| atom-strict | normal | rune:new | O2 | count | 1/1 | 9.730000000 | 9.730000000 to 9.730000000 | 1361664034/2847408344/78736141 |
| atom-strict | normal | rune:jit | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| atom-strict | normal | rune:jit | O2 | correctness | 1/1 | 5.610000000 | 5.610000000 to 5.610000000 | - |
| atom-strict | normal | rune:jit | O2 | count | 1/1 | 4.540000000 | 4.540000000 to 4.540000000 | 1361664034/2847408344/78736141 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

