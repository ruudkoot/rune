# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| floyd_warshall | normal | rune | O2 | compile | 1/1 | 2.190000000 | 2.190000000 to 2.190000000 | - |
| floyd_warshall | normal | rune | O2 | correctness | 1/1 | 0.610000000 | 0.610000000 to 0.610000000 | - |
| floyd_warshall | normal | rune | O2 | count | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | 103544721/21973456/612584 |
| floyd_warshall | normal | rune:opt | O2 | compile | 1/1 | 2.820000000 | 2.820000000 to 2.820000000 | - |
| floyd_warshall | normal | rune:opt | O2 | native-compile | 1/1 | 0.470000000 | 0.470000000 to 0.470000000 | - |
| floyd_warshall | normal | rune:opt | O2 | correctness | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | - |
| floyd_warshall | normal | rune:opt | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 103544721/21973456/612584 |
| floyd_warshall | normal | rune:new | O2 | compile | 1/1 | 2.090000000 | 2.090000000 to 2.090000000 | - |
| floyd_warshall | normal | rune:new | O2 | correctness | 1/1 | 0.830000000 | 0.830000000 to 0.830000000 | - |
| floyd_warshall | normal | rune:new | O2 | count | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | 60366314/21973456/612584 |
| floyd_warshall | normal | rune:jit | O2 | compile | 1/1 | 2.100000000 | 2.100000000 to 2.100000000 | - |
| floyd_warshall | normal | rune:jit | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| floyd_warshall | normal | rune:jit | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 60366314/21973456/612584 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

