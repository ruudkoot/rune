# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| int_find2 | normal | rune | O2 | compile | 1/1 | 2.520000000 | 2.520000000 to 2.520000000 | - |
| int_find2 | normal | rune | O2 | correctness | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | - |
| int_find2 | normal | rune | O2 | count | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | 59130830/170592/2664 |
| int_find2 | normal | rune:opt | O2 | compile | 1/1 | 2.990000000 | 2.990000000 to 2.990000000 | - |
| int_find2 | normal | rune:opt | O2 | native-compile | 1/1 | 1.650000000 | 1.650000000 to 1.650000000 | - |
| int_find2 | normal | rune:opt | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| int_find2 | normal | rune:opt | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 59130830/170592/2664 |
| int_find2 | normal | rune:new | O2 | compile | 1/1 | 3.600000000 | 3.600000000 to 3.600000000 | - |
| int_find2 | normal | rune:new | O2 | correctness | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| int_find2 | normal | rune:new | O2 | count | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | 39088470/170592/2664 |
| int_find2 | normal | rune:jit | O2 | compile | 1/1 | 3.130000000 | 3.130000000 to 3.130000000 | - |
| int_find2 | normal | rune:jit | O2 | correctness | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| int_find2 | normal | rune:jit | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 39088470/170592/2664 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

