# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_get | normal | rune | O2 | compile | 1/1 | 2.990000000 | 2.990000000 to 2.990000000 | - |
| bytes_get | normal | rune | O2 | correctness | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| bytes_get | normal | rune | O2 | count | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | 14424000/12858432/401286 |
| bytes_get | normal | rune:opt | O2 | compile | 1/1 | 3.400000000 | 3.400000000 to 3.400000000 | - |
| bytes_get | normal | rune:opt | O2 | native-compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| bytes_get | normal | rune:opt | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| bytes_get | normal | rune:opt | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 14424000/12858432/401286 |
| bytes_get | normal | rune:new | O2 | compile | 1/1 | 2.860000000 | 2.860000000 to 2.860000000 | - |
| bytes_get | normal | rune:new | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| bytes_get | normal | rune:new | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 9815273/12858432/401286 |
| bytes_get | normal | rune:jit | O2 | compile | 1/1 | 2.890000000 | 2.890000000 to 2.890000000 | - |
| bytes_get | normal | rune:jit | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| bytes_get | normal | rune:jit | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 9815273/12858432/401286 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

