# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| happy-strict | normal | rune | O2 | compile | 1/1 | 6.230000000 | 6.230000000 to 6.230000000 | - |
| happy-strict | normal | rune | O2 | correctness | 1/1 | 41.920000000 | 41.920000000 to 41.920000000 | - |
| happy-strict | normal | rune | O2 | count | 1/1 | 42.500000000 | 42.500000000 to 42.500000000 | 5949975802/11956667336/329798941 |
| happy-strict | normal | rune:opt | O2 | compile | 1/1 | 5.920000000 | 5.920000000 to 5.920000000 | - |
| happy-strict | normal | rune:opt | O2 | native-compile | 1/1 | 2.310000000 | 2.310000000 to 2.310000000 | - |
| happy-strict | normal | rune:opt | O2 | correctness | 1/1 | 20.910000000 | 20.910000000 to 20.910000000 | - |
| happy-strict | normal | rune:opt | O2 | count | 1/1 | 18.620000000 | 18.620000000 to 18.620000000 | 5949975802/11956667336/329798941 |
| happy-strict | normal | rune:new | O2 | compile | 1/1 | 6.920000000 | 6.920000000 to 6.920000000 | - |
| happy-strict | normal | rune:new | O2 | correctness | 1/1 | 51.020000000 | 51.020000000 to 51.020000000 | - |
| happy-strict | normal | rune:new | O2 | count | 1/1 | 39.870000000 | 39.870000000 to 39.870000000 | 3301006277/11956667336/329798941 |
| happy-strict | normal | rune:jit | O2 | compile | 1/1 | 8.330000000 | 8.330000000 to 8.330000000 | - |
| happy-strict | normal | rune:jit | O2 | correctness | 1/1 | 26.090000000 | 26.090000000 to 26.090000000 | - |
| happy-strict | normal | rune:jit | O2 | count | 1/1 | 28.050000000 | 28.050000000 to 28.050000000 | 3301006277/11956667336/329798941 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

