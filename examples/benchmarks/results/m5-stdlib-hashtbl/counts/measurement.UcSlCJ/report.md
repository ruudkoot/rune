# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hashtbl_add_sized | normal | rune | O2 | compile | 1/1 | 3.910000000 | 3.910000000 to 3.910000000 | - |
| hashtbl_add_sized | normal | rune | O2 | correctness | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | - |
| hashtbl_add_sized | normal | rune | O2 | count | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | 33759390/32588336/600678 |
| hashtbl_add_sized | normal | rune:opt | O2 | compile | 1/1 | 2.630000000 | 2.630000000 to 2.630000000 | - |
| hashtbl_add_sized | normal | rune:opt | O2 | native-compile | 1/1 | 0.960000000 | 0.960000000 to 0.960000000 | - |
| hashtbl_add_sized | normal | rune:opt | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| hashtbl_add_sized | normal | rune:opt | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 33759390/32588336/600678 |
| hashtbl_add_sized | normal | rune:new | O2 | compile | 1/1 | 2.650000000 | 2.650000000 to 2.650000000 | - |
| hashtbl_add_sized | normal | rune:new | O2 | correctness | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| hashtbl_add_sized | normal | rune:new | O2 | count | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | 23155634/32588336/600678 |
| hashtbl_add_sized | normal | rune:jit | O2 | compile | 1/1 | 2.530000000 | 2.530000000 to 2.530000000 | - |
| hashtbl_add_sized | normal | rune:jit | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| hashtbl_add_sized | normal | rune:jit | O2 | count | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | 23155634/32588336/600678 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

