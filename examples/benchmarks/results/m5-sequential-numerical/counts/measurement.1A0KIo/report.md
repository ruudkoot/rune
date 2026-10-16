# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| durand-kerner-aberth | normal | rune | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| durand-kerner-aberth | normal | rune | O2 | correctness | 1/1 | 3.970000000 | 3.970000000 to 3.970000000 | - |
| durand-kerner-aberth | normal | rune | O2 | count | 1/1 | 3.620000000 | 3.620000000 to 3.620000000 | 1156741993/1266296656/31468604 |
| durand-kerner-aberth | normal | rune:opt | O2 | compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| durand-kerner-aberth | normal | rune:opt | O2 | native-compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| durand-kerner-aberth | normal | rune:opt | O2 | correctness | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| durand-kerner-aberth | normal | rune:opt | O2 | count | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | 1156741993/1266296656/31468604 |
| durand-kerner-aberth | normal | rune:new | O2 | compile | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| durand-kerner-aberth | normal | rune:new | O2 | correctness | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| durand-kerner-aberth | normal | rune:new | O2 | count | 1/1 | 3.190000000 | 3.190000000 to 3.190000000 | 563350557/1266296656/31468604 |
| durand-kerner-aberth | normal | rune:jit | O2 | compile | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| durand-kerner-aberth | normal | rune:jit | O2 | correctness | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | - |
| durand-kerner-aberth | normal | rune:jit | O2 | count | 1/1 | 0.890000000 | 0.890000000 to 0.890000000 | 563350557/1266296656/31468604 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

