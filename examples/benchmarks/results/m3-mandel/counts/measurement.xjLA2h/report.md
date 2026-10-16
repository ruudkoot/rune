# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mandel-old-strict | normal | rune | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| mandel-old-strict | normal | rune | O2 | correctness | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| mandel-old-strict | normal | rune | O2 | count | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | 392616251/661995896/16736149 |
| mandel-old-strict | normal | rune:opt | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| mandel-old-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| mandel-old-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| mandel-old-strict | normal | rune:opt | O2 | count | 1/1 | 0.530000000 | 0.530000000 to 0.530000000 | 392616251/661995896/16736149 |
| mandel-old-strict | normal | rune:new | O2 | compile | 1/1 | 1.550000000 | 1.550000000 to 1.550000000 | - |
| mandel-old-strict | normal | rune:new | O2 | correctness | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| mandel-old-strict | normal | rune:new | O2 | count | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | 219218580/661995896/16736149 |
| mandel-old-strict | normal | rune:jit | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| mandel-old-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| mandel-old-strict | normal | rune:jit | O2 | count | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | 219218580/661995896/16736149 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

