# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| infer-lazy | normal | rune | O2 | compile | 1/1 | 2.530000000 | 2.530000000 to 2.530000000 | - |
| infer-lazy | normal | rune | O2 | correctness | 1/1 | 16.690000000 | 16.690000000 to 16.690000000 | - |
| infer-lazy | normal | rune | O2 | count | 1/1 | 12.880000000 | 12.880000000 to 12.880000000 | 2784771196/6893079712/204696506 |
| infer-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.290000000 | 2.290000000 to 2.290000000 | - |
| infer-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| infer-lazy | normal | rune:opt | O2 | correctness | 1/1 | 9.730000000 | 9.730000000 to 9.730000000 | - |
| infer-lazy | normal | rune:opt | O2 | count | 1/1 | 7.350000000 | 7.350000000 to 7.350000000 | 2784771196/6893079712/204696506 |
| infer-lazy | normal | rune:new | O2 | compile | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |
| infer-lazy | normal | rune:new | O2 | correctness | 1/1 | 12.860000000 | 12.860000000 to 12.860000000 | - |
| infer-lazy | normal | rune:new | O2 | count | 1/1 | 16.170000000 | 16.170000000 to 16.170000000 | 1600908047/6893079712/204696506 |
| infer-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.280000000 | 2.280000000 to 2.280000000 | - |
| infer-lazy | normal | rune:jit | O2 | correctness | 1/1 | 8.060000000 | 8.060000000 to 8.060000000 | - |
| infer-lazy | normal | rune:jit | O2 | count | 1/1 | 6.720000000 | 6.720000000 to 6.720000000 | 1600908047/6893079712/204696506 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

