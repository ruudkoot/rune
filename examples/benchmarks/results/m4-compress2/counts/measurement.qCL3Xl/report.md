# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| compress-strict | normal | rune | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| compress-strict | normal | rune | O2 | correctness | 1/1 | 2.240000000 | 2.240000000 to 2.240000000 | - |
| compress-strict | normal | rune | O2 | count | 1/1 | 2.210000000 | 2.210000000 to 2.210000000 | 766105509/1677209280/30181572 |
| compress-strict | normal | rune:opt | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| compress-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| compress-strict | normal | rune:opt | O2 | correctness | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| compress-strict | normal | rune:opt | O2 | count | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | 766105509/1677209280/30181572 |
| compress-strict | normal | rune:new | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| compress-strict | normal | rune:new | O2 | correctness | 1/1 | 1.810000000 | 1.810000000 to 1.810000000 | - |
| compress-strict | normal | rune:new | O2 | count | 1/1 | 2.460000000 | 2.460000000 to 2.460000000 | 298683885/1677209280/30181572 |
| compress-strict | normal | rune:jit | O2 | compile | 1/1 | 1.840000000 | 1.840000000 to 1.840000000 | - |
| compress-strict | normal | rune:jit | O2 | correctness | 1/1 | 1.040000000 | 1.040000000 to 1.040000000 | - |
| compress-strict | normal | rune:jit | O2 | count | 1/1 | 0.950000000 | 0.950000000 to 0.950000000 | 298683885/1677209280/30181572 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

