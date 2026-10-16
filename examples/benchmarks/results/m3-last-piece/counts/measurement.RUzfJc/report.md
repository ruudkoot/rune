# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| last-piece-lazy | normal | rune | O2 | compile | 1/1 | 2.220000000 | 2.220000000 to 2.220000000 | - |
| last-piece-lazy | normal | rune | O2 | correctness | 1/1 | 6.800000000 | 6.800000000 to 6.800000000 | - |
| last-piece-lazy | normal | rune | O2 | count | 1/1 | 6.140000000 | 6.140000000 to 6.140000000 | 1108931819/1346738384/23666418 |
| last-piece-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.940000000 | 2.940000000 to 2.940000000 | - |
| last-piece-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| last-piece-lazy | normal | rune:opt | O2 | correctness | 1/1 | 2.550000000 | 2.550000000 to 2.550000000 | - |
| last-piece-lazy | normal | rune:opt | O2 | count | 1/1 | 2.930000000 | 2.930000000 to 2.930000000 | 1108931819/1346738384/23666418 |
| last-piece-lazy | normal | rune:new | O2 | compile | 1/1 | 2.010000000 | 2.010000000 to 2.010000000 | - |
| last-piece-lazy | normal | rune:new | O2 | correctness | 1/1 | 8.040000000 | 8.040000000 to 8.040000000 | - |
| last-piece-lazy | normal | rune:new | O2 | count | 1/1 | 5.140000000 | 5.140000000 to 5.140000000 | 482002951/1346738384/23666418 |
| last-piece-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.770000000 | 1.770000000 to 1.770000000 | - |
| last-piece-lazy | normal | rune:jit | O2 | correctness | 1/1 | 1.900000000 | 1.900000000 to 1.900000000 | - |
| last-piece-lazy | normal | rune:jit | O2 | count | 1/1 | 2.140000000 | 2.140000000 to 2.140000000 | 482002951/1346738384/23666418 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

