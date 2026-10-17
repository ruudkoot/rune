# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| sphere-strict | normal | rune | O2 | compile | 1/1 | 1.820000000 | 1.820000000 to 1.820000000 | - |
| sphere-strict | normal | rune | O2 | correctness | 1/1 | 59.680000000 | 59.680000000 to 59.680000000 | - |
| sphere-strict | normal | rune | O2 | count | 1/1 | 55.640000000 | 55.640000000 to 55.640000000 | 9917407789/23644025424/617028600 |
| sphere-strict | normal | rune:opt | O2 | compile | 1/1 | 2.170000000 | 2.170000000 to 2.170000000 | - |
| sphere-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | - |
| sphere-strict | normal | rune:opt | O2 | correctness | 1/1 | 25.700000000 | 25.700000000 to 25.700000000 | - |
| sphere-strict | normal | rune:opt | O2 | count | 1/1 | 26.130000000 | 26.130000000 to 26.130000000 | 9917407789/23644025424/617028600 |
| sphere-strict | normal | rune:new | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| sphere-strict | normal | rune:new | O2 | correctness | 1/1 | 51.950000000 | 51.950000000 to 51.950000000 | - |
| sphere-strict | normal | rune:new | O2 | count | 1/1 | 52.050000000 | 52.050000000 to 52.050000000 | 5545338200/23644025424/617028600 |
| sphere-strict | normal | rune:jit | O2 | compile | 1/1 | 2.000000000 | 2.000000000 to 2.000000000 | - |
| sphere-strict | normal | rune:jit | O2 | correctness | 1/1 | 23.520000000 | 23.520000000 to 23.520000000 | - |
| sphere-strict | normal | rune:jit | O2 | count | 1/1 | 24.540000000 | 24.540000000 to 24.540000000 | 5545338200/23644025424/617028600 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

