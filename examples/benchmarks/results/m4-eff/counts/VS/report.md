# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| VS | normal | rune | O2 | compile | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |
| VS | normal | rune | O2 | correctness | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| VS | normal | rune | O2 | count | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | 118010459/560019200/12000504 |
| VS | normal | rune:opt | O2 | compile | 1/1 | 1.120000000 | 1.120000000 to 1.120000000 | - |
| VS | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| VS | normal | rune:opt | O2 | correctness | 1/1 | 1.030000000 | 1.030000000 to 1.030000000 | - |
| VS | normal | rune:opt | O2 | count | 1/1 | 0.860000000 | 0.860000000 to 0.860000000 | 118010459/560019200/12000504 |
| VS | normal | rune:new | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| VS | normal | rune:new | O2 | correctness | 1/1 | 1.380000000 | 1.380000000 to 1.380000000 | - |
| VS | normal | rune:new | O2 | count | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | 72006345/560019200/12000504 |
| VS | normal | rune:jit | O2 | compile | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| VS | normal | rune:jit | O2 | correctness | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| VS | normal | rune:jit | O2 | count | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | 72006345/560019200/12000504 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

