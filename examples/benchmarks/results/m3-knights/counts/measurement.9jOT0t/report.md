# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| knights-strict | normal | rune | O2 | compile | 1/1 | 1.930000000 | 1.930000000 to 1.930000000 | - |
| knights-strict | normal | rune | O2 | correctness | 1/1 | 22.200000000 | 22.200000000 to 22.200000000 | - |
| knights-strict | normal | rune | O2 | count | 1/1 | 22.060000000 | 22.060000000 to 22.060000000 | 3960922190/3619021864/116547197 |
| knights-strict | normal | rune:opt | O2 | compile | 1/1 | 2.040000000 | 2.040000000 to 2.040000000 | - |
| knights-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | - |
| knights-strict | normal | rune:opt | O2 | correctness | 1/1 | 11.590000000 | 11.590000000 to 11.590000000 | - |
| knights-strict | normal | rune:opt | O2 | count | 1/1 | 12.830000000 | 12.830000000 to 12.830000000 | 3960922190/3619021864/116547197 |
| knights-strict | normal | rune:new | O2 | compile | 1/1 | 2.050000000 | 2.050000000 to 2.050000000 | - |
| knights-strict | normal | rune:new | O2 | correctness | 1/1 | 23.780000000 | 23.780000000 to 23.780000000 | - |
| knights-strict | normal | rune:new | O2 | count | 1/1 | 23.560000000 | 23.560000000 to 23.560000000 | 2254972556/3619021864/116547197 |
| knights-strict | normal | rune:jit | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| knights-strict | normal | rune:jit | O2 | correctness | 1/1 | 9.260000000 | 9.260000000 to 9.260000000 | - |
| knights-strict | normal | rune:jit | O2 | count | 1/1 | 10.580000000 | 10.580000000 to 10.580000000 | 2254972556/3619021864/116547197 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

