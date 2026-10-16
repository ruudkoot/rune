# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| puzzle-lazy | normal | rune | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| puzzle-lazy | normal | rune | O2 | correctness | 1/1 | 27.670000000 | 27.670000000 to 27.670000000 | - |
| puzzle-lazy | normal | rune | O2 | count | 1/1 | 23.000000000 | 23.000000000 to 23.000000000 | 5038881692/15234790712/408351891 |
| puzzle-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.420000000 | 2.420000000 to 2.420000000 | - |
| puzzle-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| puzzle-lazy | normal | rune:opt | O2 | correctness | 1/1 | 12.140000000 | 12.140000000 to 12.140000000 | - |
| puzzle-lazy | normal | rune:opt | O2 | count | 1/1 | 13.530000000 | 13.530000000 to 13.530000000 | 5038881692/15234790712/408351891 |
| puzzle-lazy | normal | rune:new | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| puzzle-lazy | normal | rune:new | O2 | correctness | 1/1 | 24.890000000 | 24.890000000 to 24.890000000 | - |
| puzzle-lazy | normal | rune:new | O2 | count | 1/1 | 23.240000000 | 23.240000000 to 23.240000000 | 3068055688/15234790712/408351891 |
| puzzle-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| puzzle-lazy | normal | rune:jit | O2 | correctness | 1/1 | 11.490000000 | 11.490000000 to 11.490000000 | - |
| puzzle-lazy | normal | rune:jit | O2 | count | 1/1 | 12.710000000 | 12.710000000 to 12.710000000 | 3068055688/15234790712/408351891 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

