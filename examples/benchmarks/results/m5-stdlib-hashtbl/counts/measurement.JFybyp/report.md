# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| int_replace1 | normal | rune | O2 | compile | 1/1 | 3.140000000 | 3.140000000 to 3.140000000 | - |
| int_replace1 | normal | rune | O2 | correctness | 1/1 | 2.780000000 | 2.780000000 to 2.780000000 | - |
| int_replace1 | normal | rune | O2 | count | 1/1 | 2.210000000 | 2.210000000 to 2.210000000 | 283797298/104530760/1009667 |
| int_replace1 | normal | rune:opt | O2 | compile | 1/1 | 3.040000000 | 3.040000000 to 3.040000000 | - |
| int_replace1 | normal | rune:opt | O2 | native-compile | 1/1 | 0.750000000 | 0.750000000 to 0.750000000 | - |
| int_replace1 | normal | rune:opt | O2 | correctness | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | - |
| int_replace1 | normal | rune:opt | O2 | count | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | 283797298/104530760/1009667 |
| int_replace1 | normal | rune:new | O2 | compile | 1/1 | 2.590000000 | 2.590000000 to 2.590000000 | - |
| int_replace1 | normal | rune:new | O2 | correctness | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| int_replace1 | normal | rune:new | O2 | count | 1/1 | 2.060000000 | 2.060000000 to 2.060000000 | 190725967/104530760/1009667 |
| int_replace1 | normal | rune:jit | O2 | compile | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| int_replace1 | normal | rune:jit | O2 | correctness | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | - |
| int_replace1 | normal | rune:jit | O2 | count | 1/1 | 0.630000000 | 0.630000000 to 0.630000000 | 190725967/104530760/1009667 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

