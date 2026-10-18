# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fem-lazy | normal | rune | O2 | compile | 1/1 | 4.520000000 | 4.520000000 to 4.520000000 | - |
| fem-lazy | normal | rune | O2 | correctness | 1/1 | 15.050000000 | 15.050000000 to 15.050000000 | - |
| fem-lazy | normal | rune | O2 | count | 1/1 | 14.390000000 | 14.390000000 to 14.390000000 | 1871111138/5308949160/135688107 |
| fem-lazy | normal | rune:opt | O2 | compile | 1/1 | 4.380000000 | 4.380000000 to 4.380000000 | - |
| fem-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | - |
| fem-lazy | normal | rune:opt | O2 | correctness | 1/1 | 5.510000000 | 5.510000000 to 5.510000000 | - |
| fem-lazy | normal | rune:opt | O2 | count | 1/1 | 5.550000000 | 5.550000000 to 5.550000000 | 1871111138/5308949160/135688107 |
| fem-lazy | normal | rune:new | O2 | compile | 1/1 | 3.610000000 | 3.610000000 to 3.610000000 | - |
| fem-lazy | normal | rune:new | O2 | correctness | 1/1 | 13.080000000 | 13.080000000 to 13.080000000 | - |
| fem-lazy | normal | rune:new | O2 | count | 1/1 | 14.290000000 | 14.290000000 to 14.290000000 | 1100681322/5308949160/135688107 |
| fem-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.940000000 | 2.940000000 to 2.940000000 | - |
| fem-lazy | normal | rune:jit | O2 | correctness | 1/1 | 4.840000000 | 4.840000000 to 4.840000000 | - |
| fem-lazy | normal | rune:jit | O2 | count | 1/1 | 5.210000000 | 5.210000000 to 5.210000000 | 1100681322/5308949160/135688107 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

