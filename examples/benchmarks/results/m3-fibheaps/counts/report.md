# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fibheaps-lazy | normal | rune | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| fibheaps-lazy | normal | rune | O2 | correctness | 1/1 | 4.180000000 | 4.180000000 to 4.180000000 | - |
| fibheaps-lazy | normal | rune | O2 | count | 1/1 | 3.740000000 | 3.740000000 to 3.740000000 | 481787722/1443650696/43771451 |
| fibheaps-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| fibheaps-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| fibheaps-lazy | normal | rune:opt | O2 | correctness | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |
| fibheaps-lazy | normal | rune:opt | O2 | count | 1/1 | 2.160000000 | 2.160000000 to 2.160000000 | 481787722/1443650696/43771451 |
| fibheaps-lazy | normal | rune:new | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| fibheaps-lazy | normal | rune:new | O2 | correctness | 1/1 | 3.160000000 | 3.160000000 to 3.160000000 | - |
| fibheaps-lazy | normal | rune:new | O2 | count | 1/1 | 3.360000000 | 3.360000000 to 3.360000000 | 283132571/1443650696/43771451 |
| fibheaps-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| fibheaps-lazy | normal | rune:jit | O2 | correctness | 1/1 | 2.120000000 | 2.120000000 to 2.120000000 | - |
| fibheaps-lazy | normal | rune:jit | O2 | count | 1/1 | 3.680000000 | 3.680000000 to 3.680000000 | 283132571/1443650696/43771451 |
| fibheaps-strict | normal | rune | O2 | compile | 1/1 | 2.290000000 | 2.290000000 to 2.290000000 | - |
| fibheaps-strict | normal | rune | O2 | correctness | 1/1 | 0.870000000 | 0.870000000 to 0.870000000 | - |
| fibheaps-strict | normal | rune | O2 | count | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | 133903726/263291576/6442943 |
| fibheaps-strict | normal | rune:opt | O2 | compile | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | - |
| fibheaps-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| fibheaps-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.610000000 | 0.610000000 to 0.610000000 | - |
| fibheaps-strict | normal | rune:opt | O2 | count | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | 133903726/263291576/6442943 |
| fibheaps-strict | normal | rune:new | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| fibheaps-strict | normal | rune:new | O2 | correctness | 1/1 | 0.860000000 | 0.860000000 to 0.860000000 | - |
| fibheaps-strict | normal | rune:new | O2 | count | 1/1 | 0.840000000 | 0.840000000 to 0.840000000 | 68522285/263291576/6442943 |
| fibheaps-strict | normal | rune:jit | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| fibheaps-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | - |
| fibheaps-strict | normal | rune:jit | O2 | count | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | 68522285/263291576/6442943 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

