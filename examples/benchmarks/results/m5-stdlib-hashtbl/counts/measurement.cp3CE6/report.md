# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hashtbl_find | normal | rune | O2 | compile | 1/1 | 2.820000000 | 2.820000000 to 2.820000000 | - |
| hashtbl_find | normal | rune | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| hashtbl_find | normal | rune | O2 | count | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | 18082056/259296/5674 |
| hashtbl_find | normal | rune:opt | O2 | compile | 1/1 | 3.660000000 | 3.660000000 to 3.660000000 | - |
| hashtbl_find | normal | rune:opt | O2 | native-compile | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| hashtbl_find | normal | rune:opt | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| hashtbl_find | normal | rune:opt | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 18082056/259296/5674 |
| hashtbl_find | normal | rune:new | O2 | compile | 1/1 | 2.560000000 | 2.560000000 to 2.560000000 | - |
| hashtbl_find | normal | rune:new | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| hashtbl_find | normal | rune:new | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 12927125/259296/5674 |
| hashtbl_find | normal | rune:jit | O2 | compile | 1/1 | 3.170000000 | 3.170000000 to 3.170000000 | - |
| hashtbl_find | normal | rune:jit | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| hashtbl_find | normal | rune:jit | O2 | count | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | 12927125/259296/5674 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

