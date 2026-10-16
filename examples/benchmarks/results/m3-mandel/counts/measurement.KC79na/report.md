# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mandel-strict | normal | rune | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| mandel-strict | normal | rune | O2 | correctness | 1/1 | 1.950000000 | 1.950000000 to 1.950000000 | - |
| mandel-strict | normal | rune | O2 | count | 1/1 | 2.170000000 | 2.170000000 to 2.170000000 | 497729087/839495784/21173649 |
| mandel-strict | normal | rune:opt | O2 | compile | 1/1 | 1.380000000 | 1.380000000 to 1.380000000 | - |
| mandel-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| mandel-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| mandel-strict | normal | rune:opt | O2 | count | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | 497729087/839495784/21173649 |
| mandel-strict | normal | rune:new | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| mandel-strict | normal | rune:new | O2 | correctness | 1/1 | 1.830000000 | 1.830000000 to 1.830000000 | - |
| mandel-strict | normal | rune:new | O2 | count | 1/1 | 2.020000000 | 2.020000000 to 2.020000000 | 258481736/839495784/21173649 |
| mandel-strict | normal | rune:jit | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| mandel-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.620000000 | 0.620000000 to 0.620000000 | - |
| mandel-strict | normal | rune:jit | O2 | count | 1/1 | 0.620000000 | 0.620000000 to 0.620000000 | 258481736/839495784/21173649 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

