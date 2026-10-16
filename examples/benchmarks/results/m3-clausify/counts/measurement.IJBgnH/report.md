# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| clausify-strict | normal | rune | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| clausify-strict | normal | rune | O2 | correctness | 1/1 | 8.430000000 | 8.430000000 to 8.430000000 | - |
| clausify-strict | normal | rune | O2 | count | 1/1 | 7.350000000 | 7.350000000 to 7.350000000 | 2148701011/2801557944/70095053 |
| clausify-strict | normal | rune:opt | O2 | compile | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| clausify-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| clausify-strict | normal | rune:opt | O2 | correctness | 1/1 | 2.760000000 | 2.760000000 to 2.760000000 | - |
| clausify-strict | normal | rune:opt | O2 | count | 1/1 | 3.010000000 | 3.010000000 to 3.010000000 | 2148701011/2801557944/70095053 |
| clausify-strict | normal | rune:new | O2 | compile | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| clausify-strict | normal | rune:new | O2 | correctness | 1/1 | 7.190000000 | 7.190000000 to 7.190000000 | - |
| clausify-strict | normal | rune:new | O2 | count | 1/1 | 7.400000000 | 7.400000000 to 7.400000000 | 986037634/2801557944/70095053 |
| clausify-strict | normal | rune:jit | O2 | compile | 1/1 | 2.320000000 | 2.320000000 to 2.320000000 | - |
| clausify-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.830000000 | 2.830000000 to 2.830000000 | - |
| clausify-strict | normal | rune:jit | O2 | count | 1/1 | 2.760000000 | 2.760000000 to 2.760000000 | 986037634/2801557944/70095053 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

