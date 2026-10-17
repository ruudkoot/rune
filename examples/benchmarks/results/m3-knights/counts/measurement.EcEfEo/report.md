# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| knights-array-strict | normal | rune | O2 | compile | 1/1 | 1.810000000 | 1.810000000 to 1.810000000 | - |
| knights-array-strict | normal | rune | O2 | correctness | 1/1 | 10.310000000 | 10.310000000 to 10.310000000 | - |
| knights-array-strict | normal | rune | O2 | count | 1/1 | 10.500000000 | 10.500000000 to 10.500000000 | 2036258178/4637276336/98981392 |
| knights-array-strict | normal | rune:opt | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| knights-array-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| knights-array-strict | normal | rune:opt | O2 | correctness | 1/1 | 4.350000000 | 4.350000000 to 4.350000000 | - |
| knights-array-strict | normal | rune:opt | O2 | count | 1/1 | 4.540000000 | 4.540000000 to 4.540000000 | 2036258178/4637276336/98981392 |
| knights-array-strict | normal | rune:new | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| knights-array-strict | normal | rune:new | O2 | correctness | 1/1 | 8.890000000 | 8.890000000 to 8.890000000 | - |
| knights-array-strict | normal | rune:new | O2 | count | 1/1 | 8.710000000 | 8.710000000 to 8.710000000 | 1279365014/4637276336/98981392 |
| knights-array-strict | normal | rune:jit | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| knights-array-strict | normal | rune:jit | O2 | correctness | 1/1 | 4.090000000 | 4.090000000 to 4.090000000 | - |
| knights-array-strict | normal | rune:jit | O2 | count | 1/1 | 4.420000000 | 4.420000000 to 4.420000000 | 1279365014/4637276336/98981392 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

