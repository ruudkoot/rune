# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| linear-nofib-gc-strict | normal | rune | O2 | compile | 1/1 | 2.240000000 | 2.240000000 to 2.240000000 | - |
| linear-nofib-gc-strict | normal | rune | O2 | correctness | 1/1 | 41.130000000 | 41.130000000 to 41.130000000 | - |
| linear-nofib-gc-strict | normal | rune | O2 | count | 1/1 | 41.500000000 | 41.500000000 to 41.500000000 | 7060113347/7939990360/241698559 |
| linear-nofib-gc-strict | normal | rune:opt | O2 | compile | 1/1 | 2.040000000 | 2.040000000 to 2.040000000 | - |
| linear-nofib-gc-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | - |
| linear-nofib-gc-strict | normal | rune:opt | O2 | correctness | 1/1 | 23.360000000 | 23.360000000 to 23.360000000 | - |
| linear-nofib-gc-strict | normal | rune:opt | O2 | count | 1/1 | 23.750000000 | 23.750000000 to 23.750000000 | 7060113347/7939990360/241698559 |
| linear-nofib-gc-strict | normal | rune:new | O2 | compile | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| linear-nofib-gc-strict | normal | rune:new | O2 | correctness | 1/1 | 39.310000000 | 39.310000000 to 39.310000000 | - |
| linear-nofib-gc-strict | normal | rune:new | O2 | count | 1/1 | 38.410000000 | 38.410000000 to 38.410000000 | 4248692247/7939990360/241698559 |
| linear-nofib-gc-strict | normal | rune:jit | O2 | compile | 1/1 | 2.160000000 | 2.160000000 to 2.160000000 | - |
| linear-nofib-gc-strict | normal | rune:jit | O2 | correctness | 1/1 | 22.190000000 | 22.190000000 to 22.190000000 | - |
| linear-nofib-gc-strict | normal | rune:jit | O2 | count | 1/1 | 21.400000000 | 21.400000000 to 21.400000000 | 4248692247/7939990360/241698559 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

