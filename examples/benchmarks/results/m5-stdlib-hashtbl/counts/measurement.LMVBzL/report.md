# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hashtbl_add_resizing | normal | rune | O2 | compile | 1/1 | 2.610000000 | 2.610000000 to 2.610000000 | - |
| hashtbl_add_resizing | normal | rune | O2 | correctness | 1/1 | 0.790000000 | 0.790000000 to 0.790000000 | - |
| hashtbl_add_resizing | normal | rune | O2 | count | 1/1 | 0.590000000 | 0.590000000 to 0.590000000 | 54992601/34686640/600726 |
| hashtbl_add_resizing | normal | rune:opt | O2 | compile | 1/1 | 2.970000000 | 2.970000000 to 2.970000000 | - |
| hashtbl_add_resizing | normal | rune:opt | O2 | native-compile | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | - |
| hashtbl_add_resizing | normal | rune:opt | O2 | correctness | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| hashtbl_add_resizing | normal | rune:opt | O2 | count | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | 54992601/34686640/600726 |
| hashtbl_add_resizing | normal | rune:new | O2 | compile | 1/1 | 3.010000000 | 3.010000000 to 3.010000000 | - |
| hashtbl_add_resizing | normal | rune:new | O2 | correctness | 1/1 | 0.660000000 | 0.660000000 to 0.660000000 | - |
| hashtbl_add_resizing | normal | rune:new | O2 | count | 1/1 | 0.660000000 | 0.660000000 to 0.660000000 | 37670928/34686640/600726 |
| hashtbl_add_resizing | normal | rune:jit | O2 | compile | 1/1 | 2.640000000 | 2.640000000 to 2.640000000 | - |
| hashtbl_add_resizing | normal | rune:jit | O2 | correctness | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| hashtbl_add_resizing | normal | rune:jit | O2 | count | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | 37670928/34686640/600726 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

