# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_equal | normal | rune | O2 | compile | 1/1 | 2.610000000 | 2.610000000 to 2.610000000 | - |
| string_equal | normal | rune | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| string_equal | normal | rune | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 19843309/29617832/740573 |
| string_equal | normal | rune:opt | O2 | compile | 1/1 | 2.710000000 | 2.710000000 to 2.710000000 | - |
| string_equal | normal | rune:opt | O2 | native-compile | 1/1 | 1.020000000 | 1.020000000 to 1.020000000 | - |
| string_equal | normal | rune:opt | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| string_equal | normal | rune:opt | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 19843309/29617832/740573 |
| string_equal | normal | rune:new | O2 | compile | 1/1 | 3.930000000 | 3.930000000 to 3.930000000 | - |
| string_equal | normal | rune:new | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| string_equal | normal | rune:new | O2 | count | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | 9582355/29617832/740573 |
| string_equal | normal | rune:jit | O2 | compile | 1/1 | 2.710000000 | 2.710000000 to 2.710000000 | - |
| string_equal | normal | rune:jit | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| string_equal | normal | rune:jit | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 9582355/29617832/740573 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

