# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| CS | normal | rune | O2 | compile | 1/1 | 2.560000000 | 2.560000000 to 2.560000000 | - |
| CS | normal | rune | O2 | correctness | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | - |
| CS | normal | rune | O2 | count | 1/1 | 0.610000000 | 0.610000000 to 0.610000000 | 91010459/648019168/11000504 |
| CS | normal | rune:opt | O2 | compile | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | - |
| CS | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| CS | normal | rune:opt | O2 | correctness | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | - |
| CS | normal | rune:opt | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 91010459/648019168/11000504 |
| CS | normal | rune:new | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| CS | normal | rune:new | O2 | correctness | 1/1 | 0.530000000 | 0.530000000 to 0.530000000 | - |
| CS | normal | rune:new | O2 | count | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | 67006344/648019168/11000504 |
| CS | normal | rune:jit | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| CS | normal | rune:jit | O2 | correctness | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| CS | normal | rune:jit | O2 | count | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | 67006344/648019168/11000504 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

