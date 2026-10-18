# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_sub | normal | rune | O2 | compile | 1/1 | 3.810000000 | 3.810000000 to 3.810000000 | - |
| string_sub | normal | rune | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| string_sub | normal | rune | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 3930645/2906168/80709 |
| string_sub | normal | rune:opt | O2 | compile | 1/1 | 3.370000000 | 3.370000000 to 3.370000000 | - |
| string_sub | normal | rune:opt | O2 | native-compile | 1/1 | 0.840000000 | 0.840000000 to 0.840000000 | - |
| string_sub | normal | rune:opt | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| string_sub | normal | rune:opt | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 3930645/2906168/80709 |
| string_sub | normal | rune:new | O2 | compile | 1/1 | 3.950000000 | 3.950000000 to 3.950000000 | - |
| string_sub | normal | rune:new | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| string_sub | normal | rune:new | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 2626567/2906168/80709 |
| string_sub | normal | rune:jit | O2 | compile | 1/1 | 2.820000000 | 2.820000000 to 2.820000000 | - |
| string_sub | normal | rune:jit | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| string_sub | normal | rune:jit | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 2626567/2906168/80709 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

