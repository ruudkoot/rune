# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| anna-lazy | normal | rune | O2 | compile | 1/1 | 8.670000000 | 8.670000000 to 8.670000000 | - |
| anna-lazy | normal | rune | O2 | correctness | 1/1 | 52.870000000 | 52.870000000 to 52.870000000 | - |
| anna-lazy | normal | rune | O2 | count | 1/1 | 46.890000000 | 46.890000000 to 46.890000000 | 7978871893/18340078424/564625509 |
| anna-lazy | normal | rune:opt | O2 | compile | 1/1 | 11.430000000 | 11.430000000 to 11.430000000 | - |
| anna-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 2.480000000 | 2.480000000 to 2.480000000 | - |
| anna-lazy | normal | rune:opt | O2 | correctness | 1/1 | 25.150000000 | 25.150000000 to 25.150000000 | - |
| anna-lazy | normal | rune:opt | O2 | count | 1/1 | 25.540000000 | 25.540000000 to 25.540000000 | 7978871893/18340078424/564625509 |
| anna-lazy | normal | rune:new | O2 | compile | 1/1 | 7.860000000 | 7.860000000 to 7.860000000 | - |
| anna-lazy | normal | rune:new | O2 | correctness | 1/1 | 46.100000000 | 46.100000000 to 46.100000000 | - |
| anna-lazy | normal | rune:new | O2 | count | 1/1 | 45.830000000 | 45.830000000 to 45.830000000 | 4590615996/18340078424/564625509 |
| anna-lazy | normal | rune:jit | O2 | compile | 1/1 | 11.360000000 | 11.360000000 to 11.360000000 | - |
| anna-lazy | normal | rune:jit | O2 | correctness | 1/1 | 27.630000000 | 27.630000000 to 27.630000000 | - |
| anna-lazy | normal | rune:jit | O2 | count | 1/1 | 27.780000000 | 27.780000000 to 27.780000000 | 4590615996/18340078424/564625509 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

