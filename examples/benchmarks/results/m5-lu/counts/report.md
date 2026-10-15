# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| LU_decomposition | normal | rune | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| LU_decomposition | normal | rune | O2 | correctness | 1/1 | 1.990000000 | 1.990000000 to 1.990000000 | - |
| LU_decomposition | normal | rune | O2 | count | 1/1 | 2.210000000 | 2.210000000 to 2.210000000 | 422116283/499721024/9534450 |
| LU_decomposition | normal | rune:opt | O2 | compile | 1/1 | 1.770000000 | 1.770000000 to 1.770000000 | - |
| LU_decomposition | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| LU_decomposition | normal | rune:opt | O2 | correctness | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | - |
| LU_decomposition | normal | rune:opt | O2 | count | 1/1 | 0.870000000 | 0.870000000 to 0.870000000 | 422116283/499721024/9534450 |
| LU_decomposition | normal | rune:new | O2 | compile | 1/1 | 1.660000000 | 1.660000000 to 1.660000000 | - |
| LU_decomposition | normal | rune:new | O2 | correctness | 1/1 | 1.980000000 | 1.980000000 to 1.980000000 | - |
| LU_decomposition | normal | rune:new | O2 | count | 1/1 | 1.990000000 | 1.990000000 to 1.990000000 | 276422527/499721024/9534450 |
| LU_decomposition | normal | rune:jit | O2 | compile | 1/1 | 1.690000000 | 1.690000000 to 1.690000000 | - |
| LU_decomposition | normal | rune:jit | O2 | correctness | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | - |
| LU_decomposition | normal | rune:jit | O2 | count | 1/1 | 0.710000000 | 0.710000000 to 0.710000000 | 276422527/499721024/9534450 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

