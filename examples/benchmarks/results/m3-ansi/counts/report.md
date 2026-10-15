# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| ansi-lazy | normal | rune | O2 | compile | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| ansi-lazy | normal | rune | O2 | correctness | 1/1 | 62.990000000 | 62.990000000 to 62.990000000 | - |
| ansi-lazy | normal | rune | O2 | count | 1/1 | 52.760000000 | 52.760000000 to 52.760000000 | 5735408356/24074485624/636744783 |
| ansi-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.930000000 | 1.930000000 to 1.930000000 | - |
| ansi-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| ansi-lazy | normal | rune:opt | O2 | correctness | 1/1 | 21.610000000 | 21.610000000 to 21.610000000 | - |
| ansi-lazy | normal | rune:opt | O2 | count | 1/1 | 22.090000000 | 22.090000000 to 22.090000000 | 5735408356/24074485624/636744783 |
| ansi-lazy | normal | rune:new | O2 | compile | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | - |
| ansi-lazy | normal | rune:new | O2 | correctness | 1/1 | 58.740000000 | 58.740000000 to 58.740000000 | - |
| ansi-lazy | normal | rune:new | O2 | count | 1/1 | 55.950000000 | 55.950000000 to 55.950000000 | 3620593393/24074485624/636744783 |
| ansi-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.580000000 | 2.580000000 to 2.580000000 | - |
| ansi-lazy | normal | rune:jit | O2 | correctness | 1/1 | 28.010000000 | 28.010000000 to 28.010000000 | - |
| ansi-lazy | normal | rune:jit | O2 | count | 1/1 | 27.210000000 | 27.210000000 to 27.210000000 | 3620593393/24074485624/636744783 |
| ansi-strict | normal | rune | O2 | compile | 1/1 | 2.020000000 | 2.020000000 to 2.020000000 | - |
| ansi-strict | normal | rune | O2 | correctness | 1/1 | 20.910000000 | 20.910000000 to 20.910000000 | - |
| ansi-strict | normal | rune | O2 | count | 1/1 | 18.660000000 | 18.660000000 to 18.660000000 | 2028803229/8787690120/173474231 |
| ansi-strict | normal | rune:opt | O2 | compile | 1/1 | 2.000000000 | 2.000000000 to 2.000000000 | - |
| ansi-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| ansi-strict | normal | rune:opt | O2 | correctness | 1/1 | 7.970000000 | 7.970000000 to 7.970000000 | - |
| ansi-strict | normal | rune:opt | O2 | count | 1/1 | 9.140000000 | 9.140000000 to 9.140000000 | 2028803229/8787690120/173474231 |
| ansi-strict | normal | rune:new | O2 | compile | 1/1 | 2.100000000 | 2.100000000 to 2.100000000 | - |
| ansi-strict | normal | rune:new | O2 | correctness | 1/1 | 21.870000000 | 21.870000000 to 21.870000000 | - |
| ansi-strict | normal | rune:new | O2 | count | 1/1 | 22.010000000 | 22.010000000 to 22.010000000 | 1362001093/8787690120/173474231 |
| ansi-strict | normal | rune:jit | O2 | compile | 1/1 | 2.360000000 | 2.360000000 to 2.360000000 | - |
| ansi-strict | normal | rune:jit | O2 | correctness | 1/1 | 8.020000000 | 8.020000000 to 8.020000000 | - |
| ansi-strict | normal | rune:jit | O2 | count | 1/1 | 11.140000000 | 11.140000000 to 11.140000000 | 1362001093/8787690120/173474231 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

