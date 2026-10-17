# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| kb | normal | rune | O2 | compile | 1/1 | 1.820000000 | 1.820000000 to 1.820000000 | - |
| kb | normal | rune | O2 | correctness | 1/1 | 39.290000000 | 39.290000000 to 39.290000000 | - |
| kb | normal | rune | O2 | count | 1/1 | 33.540000000 | 33.540000000 to 33.540000000 | 6982787135/6339505856/157804700 |
| kb | normal | rune:opt | O2 | compile | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| kb | normal | rune:opt | O2 | native-compile | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| kb | normal | rune:opt | O2 | correctness | 1/1 | 14.760000000 | 14.760000000 to 14.760000000 | - |
| kb | normal | rune:opt | O2 | count | 1/1 | 17.940000000 | 17.940000000 to 17.940000000 | 6982787135/6339505856/157804700 |
| kb | normal | rune:new | O2 | compile | 1/1 | 1.810000000 | 1.810000000 to 1.810000000 | - |
| kb | normal | rune:new | O2 | correctness | 1/1 | 29.990000000 | 29.990000000 to 29.990000000 | - |
| kb | normal | rune:new | O2 | count | 1/1 | 31.080000000 | 31.080000000 to 31.080000000 | 3615234719/6339505856/157804700 |
| kb | normal | rune:jit | O2 | compile | 1/1 | 2.060000000 | 2.060000000 to 2.060000000 | - |
| kb | normal | rune:jit | O2 | correctness | 1/1 | 14.800000000 | 14.800000000 to 14.800000000 | - |
| kb | normal | rune:jit | O2 | count | 1/1 | 15.740000000 | 15.740000000 to 15.740000000 | 3615234719/6339505856/157804700 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

