# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| integer-strict | normal | rune | O2 | compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| integer-strict | normal | rune | O2 | correctness | 1/1 | 15.510000000 | 15.510000000 to 15.510000000 | - |
| integer-strict | normal | rune | O2 | count | 1/1 | 14.580000000 | 14.580000000 to 14.580000000 | 4085283853/5645494328/148282219 |
| integer-strict | normal | rune:opt | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| integer-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| integer-strict | normal | rune:opt | O2 | correctness | 1/1 | 6.020000000 | 6.020000000 to 6.020000000 | - |
| integer-strict | normal | rune:opt | O2 | count | 1/1 | 7.260000000 | 7.260000000 to 7.260000000 | 4085283853/5645494328/148282219 |
| integer-strict | normal | rune:new | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| integer-strict | normal | rune:new | O2 | correctness | 1/1 | 13.650000000 | 13.650000000 to 13.650000000 | - |
| integer-strict | normal | rune:new | O2 | count | 1/1 | 14.000000000 | 14.000000000 to 14.000000000 | 2316949921/5645494328/148282219 |
| integer-strict | normal | rune:jit | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| integer-strict | normal | rune:jit | O2 | correctness | 1/1 | 5.500000000 | 5.500000000 to 5.500000000 | - |
| integer-strict | normal | rune:jit | O2 | count | 1/1 | 5.620000000 | 5.620000000 to 5.620000000 | 2316949921/5645494328/148282219 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

