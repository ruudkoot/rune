# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_blit | normal | rune | O2 | compile | 1/1 | 3.170000000 | 3.170000000 to 3.170000000 | - |
| string_blit | normal | rune | O2 | correctness | 1/1 | 0.730000000 | 0.730000000 to 0.730000000 | - |
| string_blit | normal | rune | O2 | count | 1/1 | 0.830000000 | 0.830000000 to 0.830000000 | 73210665/101786200/2040709 |
| string_blit | normal | rune:opt | O2 | compile | 1/1 | 2.680000000 | 2.680000000 to 2.680000000 | - |
| string_blit | normal | rune:opt | O2 | native-compile | 1/1 | 0.990000000 | 0.990000000 to 0.990000000 | - |
| string_blit | normal | rune:opt | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| string_blit | normal | rune:opt | O2 | count | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | 73210665/101786200/2040709 |
| string_blit | normal | rune:new | O2 | compile | 1/1 | 3.110000000 | 3.110000000 to 3.110000000 | - |
| string_blit | normal | rune:new | O2 | correctness | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | - |
| string_blit | normal | rune:new | O2 | count | 1/1 | 0.810000000 | 0.810000000 to 0.810000000 | 52406582/101786200/2040709 |
| string_blit | normal | rune:jit | O2 | compile | 1/1 | 2.980000000 | 2.980000000 to 2.980000000 | - |
| string_blit | normal | rune:jit | O2 | correctness | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| string_blit | normal | rune:jit | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 52406582/101786200/2040709 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

