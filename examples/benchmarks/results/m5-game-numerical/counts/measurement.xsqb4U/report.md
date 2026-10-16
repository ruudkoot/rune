# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| nbody-sandmark | normal | rune | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| nbody-sandmark | normal | rune | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| nbody-sandmark | normal | rune | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 19639364/3808160/75546 |
| nbody-sandmark | normal | rune:opt | O2 | compile | 1/1 | 1.540000000 | 1.540000000 to 1.540000000 | - |
| nbody-sandmark | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| nbody-sandmark | normal | rune:opt | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| nbody-sandmark | normal | rune:opt | O2 | count | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | 19639364/3808160/75546 |
| nbody-sandmark | normal | rune:new | O2 | compile | 1/1 | 3.070000000 | 3.070000000 to 3.070000000 | - |
| nbody-sandmark | normal | rune:new | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| nbody-sandmark | normal | rune:new | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 12735255/3808160/75546 |
| nbody-sandmark | normal | rune:jit | O2 | compile | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| nbody-sandmark | normal | rune:jit | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| nbody-sandmark | normal | rune:jit | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 12735255/3808160/75546 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

