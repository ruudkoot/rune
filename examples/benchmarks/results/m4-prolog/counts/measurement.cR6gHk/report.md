# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| prolog-tree-strict | normal | rune | O2 | compile | 1/1 | 1.980000000 | 1.980000000 to 1.980000000 | - |
| prolog-tree-strict | normal | rune | O2 | correctness | 1/1 | 59.600000000 | 59.600000000 to 59.600000000 | - |
| prolog-tree-strict | normal | rune | O2 | count | 1/1 | 48.780000000 | 48.780000000 to 48.780000000 | 6812961969/22578748656/676068330 |
| prolog-tree-strict | normal | rune:opt | O2 | compile | 1/1 | 1.830000000 | 1.830000000 to 1.830000000 | - |
| prolog-tree-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| prolog-tree-strict | normal | rune:opt | O2 | correctness | 1/1 | 25.130000000 | 25.130000000 to 25.130000000 | - |
| prolog-tree-strict | normal | rune:opt | O2 | count | 1/1 | 25.390000000 | 25.390000000 to 25.390000000 | 6812961969/22578748656/676068330 |
| prolog-tree-strict | normal | rune:new | O2 | compile | 1/1 | 1.900000000 | 1.900000000 to 1.900000000 | - |
| prolog-tree-strict | normal | rune:new | O2 | correctness | 1/1 | 45.420000000 | 45.420000000 to 45.420000000 | - |
| prolog-tree-strict | normal | rune:new | O2 | count | 1/1 | 46.190000000 | 46.190000000 to 46.190000000 | 3975336082/22578748656/676068330 |
| prolog-tree-strict | normal | rune:jit | O2 | compile | 1/1 | 2.170000000 | 2.170000000 to 2.170000000 | - |
| prolog-tree-strict | normal | rune:jit | O2 | correctness | 1/1 | 23.190000000 | 23.190000000 to 23.190000000 | - |
| prolog-tree-strict | normal | rune:jit | O2 | count | 1/1 | 26.080000000 | 26.080000000 to 26.080000000 | 3975336082/22578748656/676068330 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

