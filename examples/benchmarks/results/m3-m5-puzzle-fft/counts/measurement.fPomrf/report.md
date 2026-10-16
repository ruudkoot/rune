# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| puzzle-strict | normal | rune | O2 | compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| puzzle-strict | normal | rune | O2 | correctness | 1/1 | 5.460000000 | 5.460000000 to 5.460000000 | - |
| puzzle-strict | normal | rune | O2 | count | 1/1 | 5.250000000 | 5.250000000 to 5.250000000 | 1424731525/2223288384/36553340 |
| puzzle-strict | normal | rune:opt | O2 | compile | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| puzzle-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| puzzle-strict | normal | rune:opt | O2 | correctness | 1/1 | 2.890000000 | 2.890000000 to 2.890000000 | - |
| puzzle-strict | normal | rune:opt | O2 | count | 1/1 | 2.810000000 | 2.810000000 to 2.810000000 | 1424731525/2223288384/36553340 |
| puzzle-strict | normal | rune:new | O2 | compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| puzzle-strict | normal | rune:new | O2 | correctness | 1/1 | 5.560000000 | 5.560000000 to 5.560000000 | - |
| puzzle-strict | normal | rune:new | O2 | count | 1/1 | 6.790000000 | 6.790000000 to 6.790000000 | 825388066/2223288384/36553340 |
| puzzle-strict | normal | rune:jit | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| puzzle-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.770000000 | 2.770000000 to 2.770000000 | - |
| puzzle-strict | normal | rune:jit | O2 | count | 1/1 | 2.730000000 | 2.730000000 to 2.730000000 | 825388066/2223288384/36553340 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

