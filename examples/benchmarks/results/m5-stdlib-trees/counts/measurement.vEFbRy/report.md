# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| set_add_rem | normal | rune | O2 | compile | 1/1 | 4.770000000 | 4.770000000 to 4.770000000 | - |
| set_add_rem | normal | rune | O2 | correctness | 1/1 | 2.270000000 | 2.270000000 to 2.270000000 | - |
| set_add_rem | normal | rune | O2 | count | 1/1 | 3.200000000 | 3.200000000 to 3.200000000 | 226505968/203616272/4291496 |
| set_add_rem | normal | rune:opt | O2 | compile | 1/1 | 5.010000000 | 5.010000000 to 5.010000000 | - |
| set_add_rem | normal | rune:opt | O2 | native-compile | 1/1 | 0.950000000 | 0.950000000 to 0.950000000 | - |
| set_add_rem | normal | rune:opt | O2 | correctness | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| set_add_rem | normal | rune:opt | O2 | count | 1/1 | 0.810000000 | 0.810000000 to 0.810000000 | 226505968/203616272/4291496 |
| set_add_rem | normal | rune:new | O2 | compile | 1/1 | 4.210000000 | 4.210000000 to 4.210000000 | - |
| set_add_rem | normal | rune:new | O2 | correctness | 1/1 | 3.630000000 | 3.630000000 to 3.630000000 | - |
| set_add_rem | normal | rune:new | O2 | count | 1/1 | 2.400000000 | 2.400000000 to 2.400000000 | 126141323/203616272/4291496 |
| set_add_rem | normal | rune:jit | O2 | compile | 1/1 | 6.420000000 | 6.420000000 to 6.420000000 | - |
| set_add_rem | normal | rune:jit | O2 | correctness | 1/1 | 0.850000000 | 0.850000000 to 0.850000000 | - |
| set_add_rem | normal | rune:jit | O2 | count | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | 126141323/203616272/4291496 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

