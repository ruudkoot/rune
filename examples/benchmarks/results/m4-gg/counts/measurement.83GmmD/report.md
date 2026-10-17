# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gg-spark-lazy | normal | rune | O2 | compile | 1/1 | 2.610000000 | 2.610000000 to 2.610000000 | - |
| gg-spark-lazy | normal | rune | O2 | correctness | 1/1 | 42.350000000 | 42.350000000 to 42.350000000 | - |
| gg-spark-lazy | normal | rune | O2 | count | 1/1 | 41.390000000 | 41.390000000 to 41.390000000 | 7206379650/16063340496/466161992 |
| gg-spark-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.890000000 | 2.890000000 to 2.890000000 | - |
| gg-spark-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| gg-spark-lazy | normal | rune:opt | O2 | correctness | 1/1 | 18.900000000 | 18.900000000 to 18.900000000 | - |
| gg-spark-lazy | normal | rune:opt | O2 | count | 1/1 | 17.580000000 | 17.580000000 to 17.580000000 | 7206379650/16063340496/466161992 |
| gg-spark-lazy | normal | rune:new | O2 | compile | 1/1 | 2.450000000 | 2.450000000 to 2.450000000 | - |
| gg-spark-lazy | normal | rune:new | O2 | correctness | 1/1 | 39.460000000 | 39.460000000 to 39.460000000 | - |
| gg-spark-lazy | normal | rune:new | O2 | count | 1/1 | 39.890000000 | 39.890000000 to 39.890000000 | 4162622438/16063340496/466161992 |
| gg-spark-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.980000000 | 2.980000000 to 2.980000000 | - |
| gg-spark-lazy | normal | rune:jit | O2 | correctness | 1/1 | 17.910000000 | 17.910000000 to 17.910000000 | - |
| gg-spark-lazy | normal | rune:jit | O2 | count | 1/1 | 18.670000000 | 18.670000000 to 18.670000000 | 4162622438/16063340496/466161992 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

