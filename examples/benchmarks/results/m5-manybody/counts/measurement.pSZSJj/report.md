# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| nbody-sandmark-multicore-numerical | normal | rune | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| nbody-sandmark-multicore-numerical | normal | rune | O2 | correctness | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| nbody-sandmark-multicore-numerical | normal | rune | O2 | count | 1/1 | 0.640000000 | 0.640000000 to 0.640000000 | 148519968/8572024/225067 |
| nbody-sandmark-multicore-numerical | normal | rune:opt | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| nbody-sandmark-multicore-numerical | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| nbody-sandmark-multicore-numerical | normal | rune:opt | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| nbody-sandmark-multicore-numerical | normal | rune:opt | O2 | count | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | 148519968/8572024/225067 |
| nbody-sandmark-multicore-numerical | normal | rune:new | O2 | compile | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| nbody-sandmark-multicore-numerical | normal | rune:new | O2 | correctness | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| nbody-sandmark-multicore-numerical | normal | rune:new | O2 | count | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | 97707002/8572024/225067 |
| nbody-sandmark-multicore-numerical | normal | rune:jit | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| nbody-sandmark-multicore-numerical | normal | rune:jit | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| nbody-sandmark-multicore-numerical | normal | rune:jit | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 97707002/8572024/225067 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

