# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| VSD | normal | rune | O2 | compile | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| VSD | normal | rune | O2 | correctness | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| VSD | normal | rune | O2 | count | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | 63010473/224019192/6000505 |
| VSD | normal | rune:opt | O2 | compile | 1/1 | 1.190000000 | 1.190000000 to 1.190000000 | - |
| VSD | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| VSD | normal | rune:opt | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| VSD | normal | rune:opt | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 63010473/224019192/6000505 |
| VSD | normal | rune:new | O2 | compile | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| VSD | normal | rune:new | O2 | correctness | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| VSD | normal | rune:new | O2 | count | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | 39006353/224019192/6000505 |
| VSD | normal | rune:jit | O2 | compile | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| VSD | normal | rune:jit | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| VSD | normal | rune:jit | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 39006353/224019192/6000505 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

