# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hashtbl_filter_map | normal | rune | O2 | compile | 1/1 | 2.610000000 | 2.610000000 to 2.610000000 | - |
| hashtbl_filter_map | normal | rune | O2 | correctness | 1/1 | 0.710000000 | 0.710000000 to 0.710000000 | - |
| hashtbl_filter_map | normal | rune | O2 | count | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | 99430888/95230064/2381098 |
| hashtbl_filter_map | normal | rune:opt | O2 | compile | 1/1 | 2.690000000 | 2.690000000 to 2.690000000 | - |
| hashtbl_filter_map | normal | rune:opt | O2 | native-compile | 1/1 | 0.770000000 | 0.770000000 to 0.770000000 | - |
| hashtbl_filter_map | normal | rune:opt | O2 | correctness | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| hashtbl_filter_map | normal | rune:opt | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 99430888/95230064/2381098 |
| hashtbl_filter_map | normal | rune:new | O2 | compile | 1/1 | 2.660000000 | 2.660000000 to 2.660000000 | - |
| hashtbl_filter_map | normal | rune:new | O2 | correctness | 1/1 | 0.530000000 | 0.530000000 to 0.530000000 | - |
| hashtbl_filter_map | normal | rune:new | O2 | count | 1/1 | 2.350000000 | 2.350000000 to 2.350000000 | 56220426/95230064/2381098 |
| hashtbl_filter_map | normal | rune:jit | O2 | compile | 1/1 | 2.750000000 | 2.750000000 to 2.750000000 | - |
| hashtbl_filter_map | normal | rune:jit | O2 | correctness | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| hashtbl_filter_map | normal | rune:jit | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 56220426/95230064/2381098 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

