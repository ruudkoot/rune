# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_trim | normal | rune | O2 | compile | 1/1 | 2.810000000 | 2.810000000 to 2.810000000 | - |
| string_trim | normal | rune | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| string_trim | normal | rune | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 19370680/2266160/80708 |
| string_trim | normal | rune:opt | O2 | compile | 1/1 | 2.510000000 | 2.510000000 to 2.510000000 | - |
| string_trim | normal | rune:opt | O2 | native-compile | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | - |
| string_trim | normal | rune:opt | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| string_trim | normal | rune:opt | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 19370680/2266160/80708 |
| string_trim | normal | rune:new | O2 | compile | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| string_trim | normal | rune:new | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| string_trim | normal | rune:new | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 12946598/2266160/80708 |
| string_trim | normal | rune:jit | O2 | compile | 1/1 | 2.860000000 | 2.860000000 to 2.860000000 | - |
| string_trim | normal | rune:jit | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| string_trim | normal | rune:jit | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 12946598/2266160/80708 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

