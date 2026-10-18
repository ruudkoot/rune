# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hashtbl_add_duplicate | normal | rune | O2 | compile | 1/1 | 2.590000000 | 2.590000000 to 2.590000000 | - |
| hashtbl_add_duplicate | normal | rune | O2 | correctness | 1/1 | 1.190000000 | 1.190000000 to 1.190000000 | - |
| hashtbl_add_duplicate | normal | rune | O2 | count | 1/1 | 1.190000000 | 1.190000000 to 1.190000000 | 106423253/67681104/1200730 |
| hashtbl_add_duplicate | normal | rune:opt | O2 | compile | 1/1 | 3.070000000 | 3.070000000 to 3.070000000 | - |
| hashtbl_add_duplicate | normal | rune:opt | O2 | native-compile | 1/1 | 0.800000000 | 0.800000000 to 0.800000000 | - |
| hashtbl_add_duplicate | normal | rune:opt | O2 | correctness | 1/1 | 0.530000000 | 0.530000000 to 0.530000000 | - |
| hashtbl_add_duplicate | normal | rune:opt | O2 | count | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | 106423253/67681104/1200730 |
| hashtbl_add_duplicate | normal | rune:new | O2 | compile | 1/1 | 3.170000000 | 3.170000000 to 3.170000000 | - |
| hashtbl_add_duplicate | normal | rune:new | O2 | correctness | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | - |
| hashtbl_add_duplicate | normal | rune:new | O2 | count | 1/1 | 1.750000000 | 1.750000000 to 1.750000000 | 73109968/67681104/1200730 |
| hashtbl_add_duplicate | normal | rune:jit | O2 | compile | 1/1 | 2.640000000 | 2.640000000 to 2.640000000 | - |
| hashtbl_add_duplicate | normal | rune:jit | O2 | correctness | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | - |
| hashtbl_add_duplicate | normal | rune:jit | O2 | count | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | 73109968/67681104/1200730 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

