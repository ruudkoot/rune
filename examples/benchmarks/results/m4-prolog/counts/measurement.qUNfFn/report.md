# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| prolog-tree-lazy | normal | rune | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| prolog-tree-lazy | normal | rune | O2 | correctness | 1/1 | 41.520000000 | 41.520000000 to 41.520000000 | - |
| prolog-tree-lazy | normal | rune | O2 | count | 1/1 | 54.440000000 | 54.440000000 to 54.440000000 | 7122800994/25379314952/763084127 |
| prolog-tree-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.930000000 | 1.930000000 to 1.930000000 | - |
| prolog-tree-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| prolog-tree-lazy | normal | rune:opt | O2 | correctness | 1/1 | 30.400000000 | 30.400000000 to 30.400000000 | - |
| prolog-tree-lazy | normal | rune:opt | O2 | count | 1/1 | 26.470000000 | 26.470000000 to 26.470000000 | 7122800994/25379314952/763084127 |
| prolog-tree-lazy | normal | rune:new | O2 | compile | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| prolog-tree-lazy | normal | rune:new | O2 | correctness | 1/1 | 49.670000000 | 49.670000000 to 49.670000000 | - |
| prolog-tree-lazy | normal | rune:new | O2 | count | 1/1 | 51.950000000 | 51.950000000 to 51.950000000 | 4188802834/25379314952/763084127 |
| prolog-tree-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.360000000 | 2.360000000 to 2.360000000 | - |
| prolog-tree-lazy | normal | rune:jit | O2 | correctness | 1/1 | 27.930000000 | 27.930000000 to 27.930000000 | - |
| prolog-tree-lazy | normal | rune:jit | O2 | count | 1/1 | 27.540000000 | 27.540000000 to 27.540000000 | 4188802834/25379314952/763084127 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

