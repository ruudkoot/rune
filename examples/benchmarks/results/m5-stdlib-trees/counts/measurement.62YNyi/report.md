# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| set_fold | normal | rune | O2 | compile | 1/1 | 3.860000000 | 3.860000000 to 3.860000000 | - |
| set_fold | normal | rune | O2 | correctness | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| set_fold | normal | rune | O2 | count | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | 221577233/1143016/23423 |
| set_fold | normal | rune:opt | O2 | compile | 1/1 | 3.270000000 | 3.270000000 to 3.270000000 | - |
| set_fold | normal | rune:opt | O2 | native-compile | 1/1 | 0.750000000 | 0.750000000 to 0.750000000 | - |
| set_fold | normal | rune:opt | O2 | correctness | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | - |
| set_fold | normal | rune:opt | O2 | count | 1/1 | 0.870000000 | 0.870000000 to 0.870000000 | 221577233/1143016/23423 |
| set_fold | normal | rune:new | O2 | compile | 1/1 | 3.090000000 | 3.090000000 to 3.090000000 | - |
| set_fold | normal | rune:new | O2 | correctness | 1/1 | 1.120000000 | 1.120000000 to 1.120000000 | - |
| set_fold | normal | rune:new | O2 | count | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | 100959996/1143016/23423 |
| set_fold | normal | rune:jit | O2 | compile | 1/1 | 3.300000000 | 3.300000000 to 3.300000000 | - |
| set_fold | normal | rune:jit | O2 | correctness | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| set_fold | normal | rune:jit | O2 | count | 1/1 | 0.860000000 | 0.860000000 to 0.860000000 | 100959996/1143016/23423 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

