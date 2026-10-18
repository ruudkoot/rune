# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| solid-strict | normal | rune | O2 | compile | 1/1 | 2.650000000 | 2.650000000 to 2.650000000 | - |
| solid-strict | normal | rune | O2 | correctness | 1/1 | 47.370000000 | 47.370000000 to 47.370000000 | - |
| solid-strict | normal | rune | O2 | count | 1/1 | 38.840000000 | 38.840000000 to 38.840000000 | 6091110225/11708433784/327012683 |
| solid-strict | normal | rune:opt | O2 | compile | 1/1 | 1.750000000 | 1.750000000 to 1.750000000 | - |
| solid-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| solid-strict | normal | rune:opt | O2 | correctness | 1/1 | 14.260000000 | 14.260000000 to 14.260000000 | - |
| solid-strict | normal | rune:opt | O2 | count | 1/1 | 11.800000000 | 11.800000000 to 11.800000000 | 6091110225/11708433784/327012683 |
| solid-strict | normal | rune:new | O2 | compile | 1/1 | 1.400000000 | 1.400000000 to 1.400000000 | - |
| solid-strict | normal | rune:new | O2 | correctness | 1/1 | 22.970000000 | 22.970000000 to 22.970000000 | - |
| solid-strict | normal | rune:new | O2 | count | 1/1 | 26.570000000 | 26.570000000 to 26.570000000 | 3382024763/11708433784/327012683 |
| solid-strict | normal | rune:jit | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| solid-strict | normal | rune:jit | O2 | correctness | 1/1 | 9.630000000 | 9.630000000 to 9.630000000 | - |
| solid-strict | normal | rune:jit | O2 | count | 1/1 | 10.980000000 | 10.980000000 to 10.980000000 | 3382024763/11708433784/327012683 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

