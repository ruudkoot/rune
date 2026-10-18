# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_map | normal | rune | O2 | compile | 1/1 | 2.540000000 | 2.540000000 to 2.540000000 | - |
| string_map | normal | rune | O2 | correctness | 1/1 | 0.680000000 | 0.680000000 to 0.680000000 | - |
| string_map | normal | rune | O2 | count | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | 58758517/93162064/2302706 |
| string_map | normal | rune:opt | O2 | compile | 1/1 | 3.650000000 | 3.650000000 to 3.650000000 | - |
| string_map | normal | rune:opt | O2 | native-compile | 1/1 | 1.000000000 | 1.000000000 to 1.000000000 | - |
| string_map | normal | rune:opt | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| string_map | normal | rune:opt | O2 | count | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | 58758517/93162064/2302706 |
| string_map | normal | rune:new | O2 | compile | 1/1 | 3.370000000 | 3.370000000 to 3.370000000 | - |
| string_map | normal | rune:new | O2 | correctness | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| string_map | normal | rune:new | O2 | count | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | 40314493/93162064/2302706 |
| string_map | normal | rune:jit | O2 | compile | 1/1 | 2.630000000 | 2.630000000 to 2.630000000 | - |
| string_map | normal | rune:jit | O2 | correctness | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| string_map | normal | rune:jit | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 40314493/93162064/2302706 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

