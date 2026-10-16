# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mandel2-strict | normal | rune | O2 | compile | 1/1 | 1.380000000 | 1.380000000 to 1.380000000 | - |
| mandel2-strict | normal | rune | O2 | correctness | 1/1 | 1.680000000 | 1.680000000 to 1.680000000 | - |
| mandel2-strict | normal | rune | O2 | count | 1/1 | 1.860000000 | 1.860000000 to 1.860000000 | 354986415/57182472/659999 |
| mandel2-strict | normal | rune:opt | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| mandel2-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| mandel2-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.980000000 | 0.980000000 to 0.980000000 | - |
| mandel2-strict | normal | rune:opt | O2 | count | 1/1 | 1.010000000 | 1.010000000 to 1.010000000 | 354986415/57182472/659999 |
| mandel2-strict | normal | rune:new | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| mandel2-strict | normal | rune:new | O2 | correctness | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| mandel2-strict | normal | rune:new | O2 | count | 1/1 | 2.040000000 | 2.040000000 to 2.040000000 | 225345731/57182472/659999 |
| mandel2-strict | normal | rune:jit | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| mandel2-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | - |
| mandel2-strict | normal | rune:jit | O2 | count | 1/1 | 0.790000000 | 0.790000000 to 0.790000000 | 225345731/57182472/659999 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

