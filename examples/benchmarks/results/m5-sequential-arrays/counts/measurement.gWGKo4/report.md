# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| matrix_multiplication | normal | rune | O2 | compile | 1/1 | 2.450000000 | 2.450000000 to 2.450000000 | - |
| matrix_multiplication | normal | rune | O2 | correctness | 1/1 | 0.850000000 | 0.850000000 to 0.850000000 | - |
| matrix_multiplication | normal | rune | O2 | count | 1/1 | 0.770000000 | 0.770000000 to 0.770000000 | 86095522/28499656/769423 |
| matrix_multiplication | normal | rune:opt | O2 | compile | 1/1 | 2.340000000 | 2.340000000 to 2.340000000 | - |
| matrix_multiplication | normal | rune:opt | O2 | native-compile | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | - |
| matrix_multiplication | normal | rune:opt | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| matrix_multiplication | normal | rune:opt | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 86095522/28499656/769423 |
| matrix_multiplication | normal | rune:new | O2 | compile | 1/1 | 2.630000000 | 2.630000000 to 2.630000000 | - |
| matrix_multiplication | normal | rune:new | O2 | correctness | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| matrix_multiplication | normal | rune:new | O2 | count | 1/1 | 0.620000000 | 0.620000000 to 0.620000000 | 60050965/28499656/769423 |
| matrix_multiplication | normal | rune:jit | O2 | compile | 1/1 | 2.360000000 | 2.360000000 to 2.360000000 | - |
| matrix_multiplication | normal | rune:jit | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| matrix_multiplication | normal | rune:jit | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 60050965/28499656/769423 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

