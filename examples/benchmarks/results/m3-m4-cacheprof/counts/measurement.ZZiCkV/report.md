# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| cacheprof-strict | normal | rune | O2 | compile | 1/1 | 6.730000000 | 6.730000000 to 6.730000000 | - |
| cacheprof-strict | normal | rune | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| cacheprof-strict | normal | rune | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 11395564/23534712/544427 |
| cacheprof-strict | normal | rune:opt | O2 | compile | 1/1 | 5.830000000 | 5.830000000 to 5.830000000 | - |
| cacheprof-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| cacheprof-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| cacheprof-strict | normal | rune:opt | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 11395564/23534712/544427 |
| cacheprof-strict | normal | rune:new | O2 | compile | 1/1 | 6.120000000 | 6.120000000 to 6.120000000 | - |
| cacheprof-strict | normal | rune:new | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| cacheprof-strict | normal | rune:new | O2 | count | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | 6499751/23534712/544427 |
| cacheprof-strict | normal | rune:jit | O2 | compile | 1/1 | 6.460000000 | 6.460000000 to 6.460000000 | - |
| cacheprof-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| cacheprof-strict | normal | rune:jit | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 6499751/23534712/544427 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

