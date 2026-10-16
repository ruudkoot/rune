# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| evolutionary_algorithm | normal | rune | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| evolutionary_algorithm | normal | rune | O2 | correctness | 1/1 | 1.010000000 | 1.010000000 to 1.010000000 | - |
| evolutionary_algorithm | normal | rune | O2 | count | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | 234035263/151884984/2727829 |
| evolutionary_algorithm | normal | rune:opt | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| evolutionary_algorithm | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| evolutionary_algorithm | normal | rune:opt | O2 | correctness | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| evolutionary_algorithm | normal | rune:opt | O2 | count | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | 234035263/151884984/2727829 |
| evolutionary_algorithm | normal | rune:new | O2 | compile | 1/1 | 1.550000000 | 1.550000000 to 1.550000000 | - |
| evolutionary_algorithm | normal | rune:new | O2 | correctness | 1/1 | 1.040000000 | 1.040000000 to 1.040000000 | - |
| evolutionary_algorithm | normal | rune:new | O2 | count | 1/1 | 0.940000000 | 0.940000000 to 0.940000000 | 134497076/151884984/2727829 |
| evolutionary_algorithm | normal | rune:jit | O2 | compile | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | - |
| evolutionary_algorithm | normal | rune:jit | O2 | correctness | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| evolutionary_algorithm | normal | rune:jit | O2 | count | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | 134497076/151884984/2727829 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

