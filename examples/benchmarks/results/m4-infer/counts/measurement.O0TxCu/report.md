# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| infer-strict | normal | rune | O2 | compile | 1/1 | 2.140000000 | 2.140000000 to 2.140000000 | - |
| infer-strict | normal | rune | O2 | correctness | 1/1 | 12.760000000 | 12.760000000 to 12.760000000 | - |
| infer-strict | normal | rune | O2 | count | 1/1 | 9.930000000 | 9.930000000 to 9.930000000 | 2294990586/6069519168/173839600 |
| infer-strict | normal | rune:opt | O2 | compile | 1/1 | 1.950000000 | 1.950000000 to 1.950000000 | - |
| infer-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | - |
| infer-strict | normal | rune:opt | O2 | correctness | 1/1 | 5.410000000 | 5.410000000 to 5.410000000 | - |
| infer-strict | normal | rune:opt | O2 | count | 1/1 | 5.160000000 | 5.160000000 to 5.160000000 | 2294990586/6069519168/173839600 |
| infer-strict | normal | rune:new | O2 | compile | 1/1 | 1.930000000 | 1.930000000 to 1.930000000 | - |
| infer-strict | normal | rune:new | O2 | correctness | 1/1 | 11.670000000 | 11.670000000 to 11.670000000 | - |
| infer-strict | normal | rune:new | O2 | count | 1/1 | 9.010000000 | 9.010000000 to 9.010000000 | 1272441085/6069519168/173839600 |
| infer-strict | normal | rune:jit | O2 | compile | 1/1 | 2.190000000 | 2.190000000 to 2.190000000 | - |
| infer-strict | normal | rune:jit | O2 | correctness | 1/1 | 4.750000000 | 4.750000000 to 4.750000000 | - |
| infer-strict | normal | rune:jit | O2 | count | 1/1 | 4.780000000 | 4.780000000 to 4.780000000 | 1272441085/6069519168/173839600 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

