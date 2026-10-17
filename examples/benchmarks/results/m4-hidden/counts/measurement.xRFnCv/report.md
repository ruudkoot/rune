# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hidden-lazy | normal | rune | O2 | compile | 1/1 | 1.680000000 | 1.680000000 to 1.680000000 | - |
| hidden-lazy | normal | rune | O2 | correctness | 1/1 | 94.490000000 | 94.490000000 to 94.490000000 | - |
| hidden-lazy | normal | rune | O2 | count | 1/1 | 111.730000000 | 111.730000000 to 111.730000000 | 16493700634/36439272392/1135040241 |
| hidden-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.390000000 | 2.390000000 to 2.390000000 | - |
| hidden-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | - |
| hidden-lazy | normal | rune:opt | O2 | correctness | 1/1 | 44.460000000 | 44.460000000 to 44.460000000 | - |
| hidden-lazy | normal | rune:opt | O2 | count | 1/1 | 43.650000000 | 43.650000000 to 43.650000000 | 16493700634/36439272392/1135040241 |
| hidden-lazy | normal | rune:new | O2 | compile | 1/1 | 4.650000000 | 4.650000000 to 4.650000000 | - |
| hidden-lazy | normal | rune:new | O2 | correctness | 1/1 | 95.010000000 | 95.010000000 to 95.010000000 | - |
| hidden-lazy | normal | rune:new | O2 | count | 1/1 | 101.110000000 | 101.110000000 to 101.110000000 | 10067367392/36439272392/1135040241 |
| hidden-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.020000000 | 2.020000000 to 2.020000000 | - |
| hidden-lazy | normal | rune:jit | O2 | correctness | 1/1 | 41.830000000 | 41.830000000 to 41.830000000 | - |
| hidden-lazy | normal | rune:jit | O2 | count | 1/1 | 46.690000000 | 46.690000000 to 46.690000000 | 10067367392/36439272392/1135040241 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

