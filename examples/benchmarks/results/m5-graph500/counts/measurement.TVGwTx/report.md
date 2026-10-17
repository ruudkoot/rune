# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| graph500-kernel1 | normal | rune | O2 | compile | 1/1 | 2.620000000 | 2.620000000 to 2.620000000 | - |
| graph500-kernel1 | normal | rune | O2 | correctness | 1/1 | 0.980000000 | 0.980000000 to 0.980000000 | - |
| graph500-kernel1 | normal | rune | O2 | count | 1/1 | 1.050000000 | 1.050000000 to 1.050000000 | 136824198/80398528/1850156 |
| graph500-kernel1 | normal | rune:opt | O2 | compile | 1/1 | 2.530000000 | 2.530000000 to 2.530000000 | - |
| graph500-kernel1 | normal | rune:opt | O2 | native-compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| graph500-kernel1 | normal | rune:opt | O2 | correctness | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| graph500-kernel1 | normal | rune:opt | O2 | count | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | 136824198/80398528/1850156 |
| graph500-kernel1 | normal | rune:new | O2 | compile | 1/1 | 2.540000000 | 2.540000000 to 2.540000000 | - |
| graph500-kernel1 | normal | rune:new | O2 | correctness | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | - |
| graph500-kernel1 | normal | rune:new | O2 | count | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | 91456480/80398528/1850156 |
| graph500-kernel1 | normal | rune:jit | O2 | compile | 1/1 | 2.760000000 | 2.760000000 to 2.760000000 | - |
| graph500-kernel1 | normal | rune:jit | O2 | correctness | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| graph500-kernel1 | normal | rune:jit | O2 | count | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | 91456480/80398528/1850156 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

