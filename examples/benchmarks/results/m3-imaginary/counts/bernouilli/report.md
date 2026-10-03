# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bernouilli-lazy | normal | rune | O2 | compile | 1/1 | 1.850000000 | 1.850000000 to 1.850000000 | - |
| bernouilli-lazy | normal | rune | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| bernouilli-lazy | normal | rune | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 29077376/46842216/1218515 |
| bernouilli-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.540000000 | 1.540000000 to 1.540000000 | - |
| bernouilli-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| bernouilli-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| bernouilli-lazy | normal | rune:opt | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 29077376/46842216/1218515 |
| bernouilli-lazy | normal | rune:new | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| bernouilli-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| bernouilli-lazy | normal | rune:new | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 15813203/46842216/1218515 |
| bernouilli-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| bernouilli-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| bernouilli-lazy | normal | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 15813203/46842216/1218515 |
| bernouilli-strict | normal | rune | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| bernouilli-strict | normal | rune | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| bernouilli-strict | normal | rune | O2 | count | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | 47579501/71436224/1808858 |
| bernouilli-strict | normal | rune:opt | O2 | compile | 1/1 | 1.870000000 | 1.870000000 to 1.870000000 | - |
| bernouilli-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| bernouilli-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| bernouilli-strict | normal | rune:opt | O2 | count | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | 47579501/71436224/1808858 |
| bernouilli-strict | normal | rune:new | O2 | compile | 1/1 | 1.920000000 | 1.920000000 to 1.920000000 | - |
| bernouilli-strict | normal | rune:new | O2 | correctness | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| bernouilli-strict | normal | rune:new | O2 | count | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | 25821567/71436224/1808858 |
| bernouilli-strict | normal | rune:jit | O2 | compile | 1/1 | 2.080000000 | 2.080000000 to 2.080000000 | - |
| bernouilli-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| bernouilli-strict | normal | rune:jit | O2 | count | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | 25821567/71436224/1808858 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

