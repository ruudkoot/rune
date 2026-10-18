# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| map_fold | normal | rune | O2 | compile | 1/1 | 5.150000000 | 5.150000000 to 5.150000000 | - |
| map_fold | normal | rune | O2 | correctness | 1/1 | 2.320000000 | 2.320000000 to 2.320000000 | - |
| map_fold | normal | rune | O2 | count | 1/1 | 4.340000000 | 4.340000000 to 4.340000000 | 327684864/17781552/317702 |
| map_fold | normal | rune:opt | O2 | compile | 1/1 | 5.650000000 | 5.650000000 to 5.650000000 | - |
| map_fold | normal | rune:opt | O2 | native-compile | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | - |
| map_fold | normal | rune:opt | O2 | correctness | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| map_fold | normal | rune:opt | O2 | count | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | 327684864/17781552/317702 |
| map_fold | normal | rune:new | O2 | compile | 1/1 | 3.850000000 | 3.850000000 to 3.850000000 | - |
| map_fold | normal | rune:new | O2 | correctness | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| map_fold | normal | rune:new | O2 | count | 1/1 | 2.180000000 | 2.180000000 to 2.180000000 | 139197247/17781552/317702 |
| map_fold | normal | rune:jit | O2 | compile | 1/1 | 2.610000000 | 2.610000000 to 2.610000000 | - |
| map_fold | normal | rune:jit | O2 | correctness | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| map_fold | normal | rune:jit | O2 | count | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | 139197247/17781552/317702 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

