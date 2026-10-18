# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| rewrite-nofib-lazy | normal | rune | O2 | compile | 1/1 | 2.030000000 | 2.030000000 to 2.030000000 | - |
| rewrite-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 39.950000000 | 39.950000000 to 39.950000000 | - |
| rewrite-nofib-lazy | normal | rune | O2 | count | 1/1 | 37.390000000 | 37.390000000 to 37.390000000 | 5595562213/16532151320/485683437 |
| rewrite-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.000000000 | 2.000000000 to 2.000000000 | - |
| rewrite-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| rewrite-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 14.880000000 | 14.880000000 to 14.880000000 | - |
| rewrite-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 20.070000000 | 20.070000000 to 20.070000000 | 5595562213/16532151320/485683437 |
| rewrite-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 2.330000000 | 2.330000000 to 2.330000000 | - |
| rewrite-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 41.060000000 | 41.060000000 to 41.060000000 | - |
| rewrite-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 42.830000000 | 42.830000000 to 42.830000000 | 3259266362/16532151320/485683437 |
| rewrite-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.220000000 | 2.220000000 to 2.220000000 | - |
| rewrite-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 19.880000000 | 19.880000000 to 19.880000000 | - |
| rewrite-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 22.450000000 | 22.450000000 to 22.450000000 | 3259266362/16532151320/485683437 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

