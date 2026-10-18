# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hashtbl_fold | normal | rune | O2 | compile | 1/1 | 4.630000000 | 4.630000000 to 4.630000000 | - |
| hashtbl_fold | normal | rune | O2 | correctness | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| hashtbl_fold | normal | rune | O2 | count | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | 40748924/251104/4668 |
| hashtbl_fold | normal | rune:opt | O2 | compile | 1/1 | 2.820000000 | 2.820000000 to 2.820000000 | - |
| hashtbl_fold | normal | rune:opt | O2 | native-compile | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | - |
| hashtbl_fold | normal | rune:opt | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| hashtbl_fold | normal | rune:opt | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 40748924/251104/4668 |
| hashtbl_fold | normal | rune:new | O2 | compile | 1/1 | 2.780000000 | 2.780000000 to 2.780000000 | - |
| hashtbl_fold | normal | rune:new | O2 | correctness | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| hashtbl_fold | normal | rune:new | O2 | count | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | 22467534/251104/4668 |
| hashtbl_fold | normal | rune:jit | O2 | compile | 1/1 | 2.900000000 | 2.900000000 to 2.900000000 | - |
| hashtbl_fold | normal | rune:jit | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| hashtbl_fold | normal | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 22467534/251104/4668 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

