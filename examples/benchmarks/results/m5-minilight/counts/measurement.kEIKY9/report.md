# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| minilight | normal | rune | O2 | compile | 1/1 | 2.150000000 | 2.150000000 to 2.150000000 | - |
| minilight | normal | rune | O2 | correctness | 1/1 | 6.840000000 | 6.840000000 to 6.840000000 | - |
| minilight | normal | rune | O2 | count | 1/1 | 7.280000000 | 7.280000000 to 7.280000000 | 1330008262/4202271448/102266059 |
| minilight | normal | rune:opt | O2 | compile | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| minilight | normal | rune:opt | O2 | native-compile | 1/1 | 0.510000000 | 0.510000000 to 0.510000000 | - |
| minilight | normal | rune:opt | O2 | correctness | 1/1 | 3.950000000 | 3.950000000 to 3.950000000 | - |
| minilight | normal | rune:opt | O2 | count | 1/1 | 5.390000000 | 5.390000000 to 5.390000000 | 1330008262/4202271448/102266059 |
| minilight | normal | rune:new | O2 | compile | 1/1 | 2.240000000 | 2.240000000 to 2.240000000 | - |
| minilight | normal | rune:new | O2 | correctness | 1/1 | 7.380000000 | 7.380000000 to 7.380000000 | - |
| minilight | normal | rune:new | O2 | count | 1/1 | 7.420000000 | 7.420000000 to 7.420000000 | 913479950/4202271448/102266059 |
| minilight | normal | rune:jit | O2 | compile | 1/1 | 2.630000000 | 2.630000000 to 2.630000000 | - |
| minilight | normal | rune:jit | O2 | correctness | 1/1 | 3.540000000 | 3.540000000 to 3.540000000 | - |
| minilight | normal | rune:jit | O2 | count | 1/1 | 3.530000000 | 3.530000000 to 3.530000000 | 913479950/4202271448/102266059 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

