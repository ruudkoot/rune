# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_contains | normal | rune | O2 | compile | 1/1 | 3.080000000 | 3.080000000 to 3.080000000 | - |
| bytes_contains | normal | rune | O2 | correctness | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| bytes_contains | normal | rune | O2 | count | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | 59024119/68858432/1801286 |
| bytes_contains | normal | rune:opt | O2 | compile | 1/1 | 2.660000000 | 2.660000000 to 2.660000000 | - |
| bytes_contains | normal | rune:opt | O2 | native-compile | 1/1 | 2.380000000 | 2.380000000 to 2.380000000 | - |
| bytes_contains | normal | rune:opt | O2 | correctness | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| bytes_contains | normal | rune:opt | O2 | count | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | 59024119/68858432/1801286 |
| bytes_contains | normal | rune:new | O2 | compile | 1/1 | 3.390000000 | 3.390000000 to 3.390000000 | - |
| bytes_contains | normal | rune:new | O2 | correctness | 1/1 | 0.590000000 | 0.590000000 to 0.590000000 | - |
| bytes_contains | normal | rune:new | O2 | count | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | 41015368/68858432/1801286 |
| bytes_contains | normal | rune:jit | O2 | compile | 1/1 | 4.360000000 | 4.360000000 to 4.360000000 | - |
| bytes_contains | normal | rune:jit | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| bytes_contains | normal | rune:jit | O2 | count | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | 41015368/68858432/1801286 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

