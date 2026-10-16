# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| boyer-nofib-strict | normal | rune | O2 | compile | 1/1 | 2.850000000 | 2.850000000 to 2.850000000 | - |
| boyer-nofib-strict | normal | rune | O2 | correctness | 1/1 | 177.600000000 | 177.600000000 to 177.600000000 | - |
| boyer-nofib-strict | normal | rune | O2 | count | 1/1 | 184.010000000 | 184.010000000 to 184.010000000 | 35961873369/108126210752/3115983502 |
| boyer-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| boyer-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| boyer-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 97.930000000 | 97.930000000 to 97.930000000 | - |
| boyer-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 92.950000000 | 92.950000000 to 92.950000000 | 35961873369/108126210752/3115983502 |
| boyer-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 2.270000000 | 2.270000000 to 2.270000000 | - |
| boyer-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 188.570000000 | 188.570000000 to 188.570000000 | - |
| boyer-nofib-strict | normal | rune:new | O2 | count | 1/1 | 184.920000000 | 184.920000000 to 184.920000000 | 18781427670/108126210752/3115983502 |
| boyer-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 2.050000000 | 2.050000000 to 2.050000000 | - |
| boyer-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 82.190000000 | 82.190000000 to 82.190000000 | - |
| boyer-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 83.000000000 | 83.000000000 to 83.000000000 | 18781427670/108126210752/3115983502 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

