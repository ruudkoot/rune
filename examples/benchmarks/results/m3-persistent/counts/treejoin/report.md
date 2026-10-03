# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| treejoin-lazy | normal | rune | O2 | compile | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| treejoin-lazy | normal | rune | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| treejoin-lazy | normal | rune | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 7993988/16594840/457077 |
| treejoin-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |
| treejoin-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| treejoin-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| treejoin-lazy | normal | rune:opt | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 7993988/16594840/457077 |
| treejoin-lazy | normal | rune:new | O2 | compile | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| treejoin-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| treejoin-lazy | normal | rune:new | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 4670667/16594840/457077 |
| treejoin-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| treejoin-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| treejoin-lazy | normal | rune:jit | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 4670667/16594840/457077 |
| treejoin-strict | normal | rune | O2 | compile | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| treejoin-strict | normal | rune | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| treejoin-strict | normal | rune | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 5091510/4159608/75825 |
| treejoin-strict | normal | rune:opt | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| treejoin-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| treejoin-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| treejoin-strict | normal | rune:opt | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 5091510/4159608/75825 |
| treejoin-strict | normal | rune:new | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| treejoin-strict | normal | rune:new | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| treejoin-strict | normal | rune:new | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 2670577/4159608/75825 |
| treejoin-strict | normal | rune:jit | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| treejoin-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| treejoin-strict | normal | rune:jit | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 2670577/4159608/75825 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

