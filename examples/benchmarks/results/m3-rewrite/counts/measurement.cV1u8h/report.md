# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| rewrite-strict | normal | rune | O2 | compile | 1/1 | 3.560000000 | 3.560000000 to 3.560000000 | - |
| rewrite-strict | normal | rune | O2 | correctness | 1/1 | 76.210000000 | 76.210000000 to 76.210000000 | - |
| rewrite-strict | normal | rune | O2 | count | 1/1 | 59.500000000 | 59.500000000 to 59.500000000 | 6185884927/18228484872/541009047 |
| rewrite-strict | normal | rune:opt | O2 | compile | 1/1 | 2.060000000 | 2.060000000 to 2.060000000 | - |
| rewrite-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | - |
| rewrite-strict | normal | rune:opt | O2 | correctness | 1/1 | 18.200000000 | 18.200000000 to 18.200000000 | - |
| rewrite-strict | normal | rune:opt | O2 | count | 1/1 | 20.320000000 | 20.320000000 to 20.320000000 | 6185884927/18228484872/541009047 |
| rewrite-strict | normal | rune:new | O2 | compile | 1/1 | 3.130000000 | 3.130000000 to 3.130000000 | - |
| rewrite-strict | normal | rune:new | O2 | correctness | 1/1 | 61.830000000 | 61.830000000 to 61.830000000 | - |
| rewrite-strict | normal | rune:new | O2 | count | 1/1 | 61.610000000 | 61.610000000 to 61.610000000 | 3604996325/18228484872/541009047 |
| rewrite-strict | normal | rune:jit | O2 | compile | 1/1 | 2.040000000 | 2.040000000 to 2.040000000 | - |
| rewrite-strict | normal | rune:jit | O2 | correctness | 1/1 | 23.110000000 | 23.110000000 to 23.110000000 | - |
| rewrite-strict | normal | rune:jit | O2 | count | 1/1 | 18.480000000 | 18.480000000 to 18.480000000 | 3604996325/18228484872/541009047 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

