# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| treejoin-nofib-lazy | normal | rune | O2 | compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| treejoin-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 2.870000000 | 2.870000000 to 2.870000000 | - |
| treejoin-nofib-lazy | normal | rune | O2 | count | 1/1 | 2.870000000 | 2.870000000 to 2.870000000 | 589379218/1219571688/33649621 |
| treejoin-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| treejoin-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| treejoin-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| treejoin-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 1.540000000 | 1.540000000 to 1.540000000 | 589379218/1219571688/33649621 |
| treejoin-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 1.060000000 | 1.060000000 to 1.060000000 | - |
| treejoin-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 2.750000000 | 2.750000000 to 2.750000000 | - |
| treejoin-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 2.610000000 | 2.610000000 to 2.610000000 | 344547624/1219571688/33649621 |
| treejoin-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| treejoin-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| treejoin-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | 344547624/1219571688/33649621 |
| treejoin-nofib-strict | normal | rune | O2 | compile | 1/1 | 1.060000000 | 1.060000000 to 1.060000000 | - |
| treejoin-nofib-strict | normal | rune | O2 | correctness | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| treejoin-nofib-strict | normal | rune | O2 | count | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | 375920344/300645976/5474117 |
| treejoin-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| treejoin-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| treejoin-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| treejoin-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | 375920344/300645976/5474117 |
| treejoin-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| treejoin-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 0.970000000 | 0.970000000 to 0.970000000 | - |
| treejoin-nofib-strict | normal | rune:new | O2 | count | 1/1 | 0.920000000 | 0.920000000 to 0.920000000 | 197631040/300645976/5474117 |
| treejoin-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 1.120000000 | 1.120000000 to 1.120000000 | - |
| treejoin-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| treejoin-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | 197631040/300645976/5474117 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

