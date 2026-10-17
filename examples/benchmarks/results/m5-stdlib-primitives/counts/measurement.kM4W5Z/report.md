# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| array_forall | normal | rune | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| array_forall | normal | rune | O2 | correctness | 1/1 | 0.850000000 | 0.850000000 to 0.850000000 | - |
| array_forall | normal | rune | O2 | count | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | 220639184/494192/11592 |
| array_forall | normal | rune:opt | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| array_forall | normal | rune:opt | O2 | native-compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| array_forall | normal | rune:opt | O2 | correctness | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| array_forall | normal | rune:opt | O2 | count | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | 220639184/494192/11592 |
| array_forall | normal | rune:new | O2 | compile | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| array_forall | normal | rune:new | O2 | correctness | 1/1 | 0.770000000 | 0.770000000 to 0.770000000 | - |
| array_forall | normal | rune:new | O2 | count | 1/1 | 0.630000000 | 0.630000000 to 0.630000000 | 150478427/494192/11592 |
| array_forall | normal | rune:jit | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| array_forall | normal | rune:jit | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| array_forall | normal | rune:jit | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 150478427/494192/11592 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

