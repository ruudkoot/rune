# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hashtbl_remove | normal | rune | O2 | compile | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | - |
| hashtbl_remove | normal | rune | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| hashtbl_remove | normal | rune | O2 | count | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | 36632810/12280192/304476 |
| hashtbl_remove | normal | rune:opt | O2 | compile | 1/1 | 2.270000000 | 2.270000000 to 2.270000000 | - |
| hashtbl_remove | normal | rune:opt | O2 | native-compile | 1/1 | 0.970000000 | 0.970000000 to 0.970000000 | - |
| hashtbl_remove | normal | rune:opt | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| hashtbl_remove | normal | rune:opt | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 36632810/12280192/304476 |
| hashtbl_remove | normal | rune:new | O2 | compile | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| hashtbl_remove | normal | rune:new | O2 | correctness | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| hashtbl_remove | normal | rune:new | O2 | count | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | 25155971/12280192/304476 |
| hashtbl_remove | normal | rune:jit | O2 | compile | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| hashtbl_remove | normal | rune:jit | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| hashtbl_remove | normal | rune:jit | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 25155971/12280192/304476 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

