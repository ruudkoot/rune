# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bspt-lazy | normal | rune | O2 | compile | 1/1 | 3.300000000 | 3.300000000 to 3.300000000 | - |
| bspt-lazy | normal | rune | O2 | correctness | 1/1 | 92.760000000 | 92.760000000 to 92.760000000 | - |
| bspt-lazy | normal | rune | O2 | count | 1/1 | 79.060000000 | 79.060000000 to 79.060000000 | 15296371288/11069658616/329414425 |
| bspt-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.850000000 | 2.850000000 to 2.850000000 | - |
| bspt-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.950000000 | 0.950000000 to 0.950000000 | - |
| bspt-lazy | normal | rune:opt | O2 | correctness | 1/1 | 27.360000000 | 27.360000000 to 27.360000000 | - |
| bspt-lazy | normal | rune:opt | O2 | count | 1/1 | 26.750000000 | 26.750000000 to 26.750000000 | 15296371288/11069658616/329414425 |
| bspt-lazy | normal | rune:new | O2 | compile | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| bspt-lazy | normal | rune:new | O2 | correctness | 1/1 | 65.560000000 | 65.560000000 to 65.560000000 | - |
| bspt-lazy | normal | rune:new | O2 | count | 1/1 | 68.900000000 | 68.900000000 to 68.900000000 | 9044469067/11069658616/329414425 |
| bspt-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.450000000 | 3.450000000 to 3.450000000 | - |
| bspt-lazy | normal | rune:jit | O2 | correctness | 1/1 | 27.050000000 | 27.050000000 to 27.050000000 | - |
| bspt-lazy | normal | rune:jit | O2 | count | 1/1 | 19.710000000 | 19.710000000 to 19.710000000 | 9044469067/11069658616/329414425 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

