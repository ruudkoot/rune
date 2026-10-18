# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_contains | normal | rune | O2 | compile | 1/1 | 3.990000000 | 3.990000000 to 3.990000000 | - |
| string_contains | normal | rune | O2 | correctness | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| string_contains | normal | rune | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 37410895/4826288/200712 |
| string_contains | normal | rune:opt | O2 | compile | 1/1 | 3.360000000 | 3.360000000 to 3.360000000 | - |
| string_contains | normal | rune:opt | O2 | native-compile | 1/1 | 0.770000000 | 0.770000000 to 0.770000000 | - |
| string_contains | normal | rune:opt | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| string_contains | normal | rune:opt | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 37410895/4826288/200712 |
| string_contains | normal | rune:new | O2 | compile | 1/1 | 2.560000000 | 2.560000000 to 2.560000000 | - |
| string_contains | normal | rune:new | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| string_contains | normal | rune:new | O2 | count | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | 24006740/4826288/200712 |
| string_contains | normal | rune:jit | O2 | compile | 1/1 | 2.850000000 | 2.850000000 to 2.850000000 | - |
| string_contains | normal | rune:jit | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| string_contains | normal | rune:jit | O2 | count | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | 24006740/4826288/200712 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

