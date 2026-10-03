# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gcd-lazy | normal | rune | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| gcd-lazy | normal | rune | O2 | correctness | 1/1 | 0.660000000 | 0.660000000 to 0.660000000 | - |
| gcd-lazy | normal | rune | O2 | count | 1/1 | 0.620000000 | 0.620000000 to 0.620000000 | 134817853/226483088/6281542 |
| gcd-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| gcd-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| gcd-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| gcd-lazy | normal | rune:opt | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 134817853/226483088/6281542 |
| gcd-lazy | normal | rune:new | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| gcd-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.560000000 | 0.560000000 to 0.560000000 | - |
| gcd-lazy | normal | rune:new | O2 | count | 1/1 | 0.550000000 | 0.550000000 to 0.550000000 | 77053742/226483088/6281542 |
| gcd-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| gcd-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| gcd-lazy | normal | rune:jit | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 77053742/226483088/6281542 |
| gcd-strict | normal | rune | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| gcd-strict | normal | rune | O2 | correctness | 1/1 | 0.660000000 | 0.660000000 to 0.660000000 | - |
| gcd-strict | normal | rune | O2 | count | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | 131369455/200351904/5456532 |
| gcd-strict | normal | rune:opt | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| gcd-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| gcd-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| gcd-strict | normal | rune:opt | O2 | count | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | 131369455/200351904/5456532 |
| gcd-strict | normal | rune:new | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| gcd-strict | normal | rune:new | O2 | correctness | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | - |
| gcd-strict | normal | rune:new | O2 | count | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | 74613566/200351904/5456532 |
| gcd-strict | normal | rune:jit | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| gcd-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| gcd-strict | normal | rune:jit | O2 | count | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | 74613566/200351904/5456532 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

