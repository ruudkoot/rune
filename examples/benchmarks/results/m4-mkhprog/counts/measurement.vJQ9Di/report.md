# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mkhprog-lazy | normal | rune | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| mkhprog-lazy | normal | rune | O2 | correctness | 1/1 | 91.170000000 | 91.170000000 to 91.170000000 | - |
| mkhprog-lazy | normal | rune | O2 | count | 1/1 | 81.330000000 | 81.330000000 to 81.330000000 | 17203626051/60319332232/1768231169 |
| mkhprog-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| mkhprog-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| mkhprog-lazy | normal | rune:opt | O2 | correctness | 1/1 | 42.520000000 | 42.520000000 to 42.520000000 | - |
| mkhprog-lazy | normal | rune:opt | O2 | count | 1/1 | 43.610000000 | 43.610000000 to 43.610000000 | 17203626051/60319332232/1768231169 |
| mkhprog-lazy | normal | rune:new | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| mkhprog-lazy | normal | rune:new | O2 | correctness | 1/1 | 84.420000000 | 84.420000000 to 84.420000000 | - |
| mkhprog-lazy | normal | rune:new | O2 | count | 1/1 | 82.860000000 | 82.860000000 to 82.860000000 | 10529587001/60319332232/1768231169 |
| mkhprog-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| mkhprog-lazy | normal | rune:jit | O2 | correctness | 1/1 | 47.830000000 | 47.830000000 to 47.830000000 | - |
| mkhprog-lazy | normal | rune:jit | O2 | count | 1/1 | 48.210000000 | 48.210000000 to 48.210000000 | 10529587001/60319332232/1768231169 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

