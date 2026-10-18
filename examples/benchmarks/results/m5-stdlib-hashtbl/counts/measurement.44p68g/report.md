# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hashtbl_iter | normal | rune | O2 | compile | 1/1 | 3.170000000 | 3.170000000 to 3.170000000 | - |
| hashtbl_iter | normal | rune | O2 | correctness | 1/1 | 0.510000000 | 0.510000000 to 0.510000000 | - |
| hashtbl_iter | normal | rune | O2 | count | 1/1 | 0.800000000 | 0.800000000 to 0.800000000 | 55755920/56331104/1006668 |
| hashtbl_iter | normal | rune:opt | O2 | compile | 1/1 | 3.150000000 | 3.150000000 to 3.150000000 | - |
| hashtbl_iter | normal | rune:opt | O2 | native-compile | 1/1 | 0.770000000 | 0.770000000 to 0.770000000 | - |
| hashtbl_iter | normal | rune:opt | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| hashtbl_iter | normal | rune:opt | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 55755920/56331104/1006668 |
| hashtbl_iter | normal | rune:new | O2 | compile | 1/1 | 3.200000000 | 3.200000000 to 3.200000000 | - |
| hashtbl_iter | normal | rune:new | O2 | correctness | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| hashtbl_iter | normal | rune:new | O2 | count | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | 34473530/56331104/1006668 |
| hashtbl_iter | normal | rune:jit | O2 | compile | 1/1 | 3.130000000 | 3.130000000 to 3.130000000 | - |
| hashtbl_iter | normal | rune:jit | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| hashtbl_iter | normal | rune:jit | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 34473530/56331104/1006668 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

