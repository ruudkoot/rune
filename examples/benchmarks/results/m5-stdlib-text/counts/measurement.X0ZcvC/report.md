# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_get | normal | rune | O2 | compile | 1/1 | 2.630000000 | 2.630000000 to 2.630000000 | - |
| string_get | normal | rune | O2 | correctness | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | - |
| string_get | normal | rune | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 13210784/4826288/200712 |
| string_get | normal | rune:opt | O2 | compile | 1/1 | 2.680000000 | 2.680000000 to 2.680000000 | - |
| string_get | normal | rune:opt | O2 | native-compile | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | - |
| string_get | normal | rune:opt | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| string_get | normal | rune:opt | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 13210784/4826288/200712 |
| string_get | normal | rune:new | O2 | compile | 1/1 | 2.960000000 | 2.960000000 to 2.960000000 | - |
| string_get | normal | rune:new | O2 | correctness | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| string_get | normal | rune:new | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 8806653/4826288/200712 |
| string_get | normal | rune:jit | O2 | compile | 1/1 | 2.700000000 | 2.700000000 to 2.700000000 | - |
| string_get | normal | rune:jit | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| string_get | normal | rune:jit | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 8806653/4826288/200712 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

