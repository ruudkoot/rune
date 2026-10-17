# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gg-strict | normal | rune | O2 | compile | 1/1 | 2.240000000 | 2.240000000 to 2.240000000 | - |
| gg-strict | normal | rune | O2 | correctness | 1/1 | 32.190000000 | 32.190000000 to 32.190000000 | - |
| gg-strict | normal | rune | O2 | count | 1/1 | 32.090000000 | 32.090000000 to 32.090000000 | 6967185355/15828976368/458108488 |
| gg-strict | normal | rune:opt | O2 | compile | 1/1 | 2.350000000 | 2.350000000 to 2.350000000 | - |
| gg-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.590000000 | 0.590000000 to 0.590000000 | - |
| gg-strict | normal | rune:opt | O2 | correctness | 1/1 | 18.640000000 | 18.640000000 to 18.640000000 | - |
| gg-strict | normal | rune:opt | O2 | count | 1/1 | 15.990000000 | 15.990000000 to 15.990000000 | 6967185355/15828976368/458108488 |
| gg-strict | normal | rune:new | O2 | compile | 1/1 | 2.280000000 | 2.280000000 to 2.280000000 | - |
| gg-strict | normal | rune:new | O2 | correctness | 1/1 | 29.780000000 | 29.780000000 to 29.780000000 | - |
| gg-strict | normal | rune:new | O2 | count | 1/1 | 29.810000000 | 29.810000000 to 29.810000000 | 4010294233/15828976368/458108488 |
| gg-strict | normal | rune:jit | O2 | compile | 1/1 | 2.300000000 | 2.300000000 to 2.300000000 | - |
| gg-strict | normal | rune:jit | O2 | correctness | 1/1 | 14.220000000 | 14.220000000 to 14.220000000 | - |
| gg-strict | normal | rune:jit | O2 | count | 1/1 | 16.000000000 | 16.000000000 to 16.000000000 | 4010294233/15828976368/458108488 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

