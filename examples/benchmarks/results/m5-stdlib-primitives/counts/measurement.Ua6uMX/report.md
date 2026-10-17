# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| array_fold | normal | rune | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| array_fold | normal | rune | O2 | correctness | 1/1 | 1.010000000 | 1.010000000 to 1.010000000 | - |
| array_fold | normal | rune | O2 | count | 1/1 | 1.050000000 | 1.050000000 to 1.050000000 | 280620667/560336136/10011643 |
| array_fold | normal | rune:opt | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| array_fold | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| array_fold | normal | rune:opt | O2 | correctness | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| array_fold | normal | rune:opt | O2 | count | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | 280620667/560336136/10011643 |
| array_fold | normal | rune:new | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| array_fold | normal | rune:new | O2 | correctness | 1/1 | 0.870000000 | 0.870000000 to 0.870000000 | - |
| array_fold | normal | rune:new | O2 | count | 1/1 | 1.010000000 | 1.010000000 to 1.010000000 | 140449279/560336136/10011643 |
| array_fold | normal | rune:jit | O2 | compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| array_fold | normal | rune:jit | O2 | correctness | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| array_fold | normal | rune:jit | O2 | count | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | 140449279/560336136/10011643 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

