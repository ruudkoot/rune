# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| event-strict | normal | rune | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| event-strict | normal | rune | O2 | correctness | 1/1 | 28.850000000 | 28.850000000 to 28.850000000 | - |
| event-strict | normal | rune | O2 | count | 1/1 | 24.280000000 | 24.280000000 to 24.280000000 | 4375974229/8862101712/251828246 |
| event-strict | normal | rune:opt | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| event-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| event-strict | normal | rune:opt | O2 | correctness | 1/1 | 10.250000000 | 10.250000000 to 10.250000000 | - |
| event-strict | normal | rune:opt | O2 | count | 1/1 | 10.620000000 | 10.620000000 to 10.620000000 | 4375974229/8862101712/251828246 |
| event-strict | normal | rune:new | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| event-strict | normal | rune:new | O2 | correctness | 1/1 | 21.550000000 | 21.550000000 to 21.550000000 | - |
| event-strict | normal | rune:new | O2 | count | 1/1 | 19.560000000 | 19.560000000 to 19.560000000 | 2576192219/8862101712/251828246 |
| event-strict | normal | rune:jit | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| event-strict | normal | rune:jit | O2 | correctness | 1/1 | 9.620000000 | 9.620000000 to 9.620000000 | - |
| event-strict | normal | rune:jit | O2 | count | 1/1 | 9.440000000 | 9.440000000 to 9.440000000 | 2576192219/8862101712/251828246 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

