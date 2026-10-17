# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| typecheck-lazy | normal | rune | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| typecheck-lazy | normal | rune | O2 | correctness | 1/1 | 21.710000000 | 21.710000000 to 21.710000000 | - |
| typecheck-lazy | normal | rune | O2 | count | 1/1 | 21.040000000 | 21.040000000 to 21.040000000 | 3662834798/12300269152/395807078 |
| typecheck-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| typecheck-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| typecheck-lazy | normal | rune:opt | O2 | correctness | 1/1 | 13.970000000 | 13.970000000 to 13.970000000 | - |
| typecheck-lazy | normal | rune:opt | O2 | count | 1/1 | 15.710000000 | 15.710000000 to 15.710000000 | 3662834798/12300269152/395807078 |
| typecheck-lazy | normal | rune:new | O2 | compile | 1/1 | 2.040000000 | 2.040000000 to 2.040000000 | - |
| typecheck-lazy | normal | rune:new | O2 | correctness | 1/1 | 26.780000000 | 26.780000000 to 26.780000000 | - |
| typecheck-lazy | normal | rune:new | O2 | count | 1/1 | 28.270000000 | 28.270000000 to 28.270000000 | 2165975372/12300269152/395807078 |
| typecheck-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.950000000 | 1.950000000 to 1.950000000 | - |
| typecheck-lazy | normal | rune:jit | O2 | correctness | 1/1 | 14.320000000 | 14.320000000 to 14.320000000 | - |
| typecheck-lazy | normal | rune:jit | O2 | count | 1/1 | 14.210000000 | 14.210000000 to 14.210000000 | 2165975372/12300269152/395807078 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

