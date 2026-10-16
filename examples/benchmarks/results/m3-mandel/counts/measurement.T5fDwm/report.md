# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mandel-lazy | normal | rune | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| mandel-lazy | normal | rune | O2 | correctness | 1/1 | 2.020000000 | 2.020000000 to 2.020000000 | - |
| mandel-lazy | normal | rune | O2 | count | 1/1 | 2.100000000 | 2.100000000 to 2.100000000 | 289257559/541863080/15708353 |
| mandel-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.170000000 | 2.170000000 to 2.170000000 | - |
| mandel-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | - |
| mandel-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| mandel-lazy | normal | rune:opt | O2 | count | 1/1 | 0.710000000 | 0.710000000 to 0.710000000 | 289257559/541863080/15708353 |
| mandel-lazy | normal | rune:new | O2 | compile | 1/1 | 1.920000000 | 1.920000000 to 1.920000000 | - |
| mandel-lazy | normal | rune:new | O2 | correctness | 1/1 | 3.730000000 | 3.730000000 to 3.730000000 | - |
| mandel-lazy | normal | rune:new | O2 | count | 1/1 | 2.040000000 | 2.040000000 to 2.040000000 | 167780118/541863080/15708353 |
| mandel-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.560000000 | 2.560000000 to 2.560000000 | - |
| mandel-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.770000000 | 0.770000000 to 0.770000000 | - |
| mandel-lazy | normal | rune:jit | O2 | count | 1/1 | 0.560000000 | 0.560000000 to 0.560000000 | 167780118/541863080/15708353 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

