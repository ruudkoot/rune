# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| cacheprof-lazy | normal | rune | O2 | compile | 1/1 | 4.310000000 | 4.310000000 to 4.310000000 | - |
| cacheprof-lazy | normal | rune | O2 | correctness | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| cacheprof-lazy | normal | rune | O2 | count | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | 14293630/33233648/867204 |
| cacheprof-lazy | normal | rune:opt | O2 | compile | 1/1 | 5.970000000 | 5.970000000 to 5.970000000 | - |
| cacheprof-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| cacheprof-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| cacheprof-lazy | normal | rune:opt | O2 | count | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | 14293630/33233648/867204 |
| cacheprof-lazy | normal | rune:new | O2 | compile | 1/1 | 8.340000000 | 8.340000000 to 8.340000000 | - |
| cacheprof-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| cacheprof-lazy | normal | rune:new | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 8221454/33233648/867204 |
| cacheprof-lazy | normal | rune:jit | O2 | compile | 1/1 | 10.850000000 | 10.850000000 to 10.850000000 | - |
| cacheprof-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| cacheprof-lazy | normal | rune:jit | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 8221454/33233648/867204 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

