# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_index | normal | rune | O2 | compile | 1/1 | 2.920000000 | 2.920000000 to 2.920000000 | - |
| string_index | normal | rune | O2 | correctness | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| string_index | normal | rune | O2 | count | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | 39410843/4826288/200712 |
| string_index | normal | rune:opt | O2 | compile | 1/1 | 2.900000000 | 2.900000000 to 2.900000000 | - |
| string_index | normal | rune:opt | O2 | native-compile | 1/1 | 0.870000000 | 0.870000000 to 0.870000000 | - |
| string_index | normal | rune:opt | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| string_index | normal | rune:opt | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 39410843/4826288/200712 |
| string_index | normal | rune:new | O2 | compile | 1/1 | 2.980000000 | 2.980000000 to 2.980000000 | - |
| string_index | normal | rune:new | O2 | correctness | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| string_index | normal | rune:new | O2 | count | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | 25406703/4826288/200712 |
| string_index | normal | rune:jit | O2 | compile | 1/1 | 2.910000000 | 2.910000000 to 2.910000000 | - |
| string_index | normal | rune:jit | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| string_index | normal | rune:jit | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 25406703/4826288/200712 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

