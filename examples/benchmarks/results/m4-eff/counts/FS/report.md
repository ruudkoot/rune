# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| FS | normal | rune | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| FS | normal | rune | O2 | correctness | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| FS | normal | rune | O2 | count | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | 243010495/784019232/24000508 |
| FS | normal | rune:opt | O2 | compile | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| FS | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| FS | normal | rune:opt | O2 | correctness | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| FS | normal | rune:opt | O2 | count | 1/1 | 0.530000000 | 0.530000000 to 0.530000000 | 243010495/784019232/24000508 |
| FS | normal | rune:new | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| FS | normal | rune:new | O2 | correctness | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |
| FS | normal | rune:new | O2 | count | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | 148006359/784019232/24000508 |
| FS | normal | rune:jit | O2 | compile | 1/1 | 1.080000000 | 1.080000000 to 1.080000000 | - |
| FS | normal | rune:jit | O2 | correctness | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| FS | normal | rune:jit | O2 | count | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | 148006359/784019232/24000508 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

