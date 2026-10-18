# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| dom-lt | normal | rune | O2 | compile | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | - |
| dom-lt | normal | rune | O2 | correctness | 1/1 | 65.210000000 | 65.210000000 to 65.210000000 | - |
| dom-lt | normal | rune | O2 | count | 1/1 | 57.020000000 | 57.020000000 to 57.020000000 | 10768716294/29830898776/529551763 |
| dom-lt | normal | rune:opt | O2 | compile | 1/1 | 2.050000000 | 2.050000000 to 2.050000000 | - |
| dom-lt | normal | rune:opt | O2 | native-compile | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | - |
| dom-lt | normal | rune:opt | O2 | correctness | 1/1 | 23.470000000 | 23.470000000 to 23.470000000 | - |
| dom-lt | normal | rune:opt | O2 | count | 1/1 | 24.120000000 | 24.120000000 to 24.120000000 | 10768716294/29830898776/529551763 |
| dom-lt | normal | rune:new | O2 | compile | 1/1 | 2.000000000 | 2.000000000 to 2.000000000 | - |
| dom-lt | normal | rune:new | O2 | correctness | 1/1 | 51.710000000 | 51.710000000 to 51.710000000 | - |
| dom-lt | normal | rune:new | O2 | count | 1/1 | 52.580000000 | 52.580000000 to 52.580000000 | 6642823194/29830898776/529551763 |
| dom-lt | normal | rune:jit | O2 | compile | 1/1 | 2.270000000 | 2.270000000 to 2.270000000 | - |
| dom-lt | normal | rune:jit | O2 | correctness | 1/1 | 23.490000000 | 23.490000000 to 23.490000000 | - |
| dom-lt | normal | rune:jit | O2 | count | 1/1 | 23.400000000 | 23.400000000 to 23.400000000 | 6642823194/29830898776/529551763 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

