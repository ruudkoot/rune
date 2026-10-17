# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| multiplier-strict | normal | rune | O2 | compile | 1/1 | 2.160000000 | 2.160000000 to 2.160000000 | - |
| multiplier-strict | normal | rune | O2 | correctness | 1/1 | 45.610000000 | 45.610000000 to 45.610000000 | - |
| multiplier-strict | normal | rune | O2 | count | 1/1 | 33.560000000 | 33.560000000 to 33.560000000 | 4999162367/12841520112/374553042 |
| multiplier-strict | normal | rune:opt | O2 | compile | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |
| multiplier-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| multiplier-strict | normal | rune:opt | O2 | correctness | 1/1 | 19.220000000 | 19.220000000 to 19.220000000 | - |
| multiplier-strict | normal | rune:opt | O2 | count | 1/1 | 20.730000000 | 20.730000000 to 20.730000000 | 4999162367/12841520112/374553042 |
| multiplier-strict | normal | rune:new | O2 | compile | 1/1 | 2.310000000 | 2.310000000 to 2.310000000 | - |
| multiplier-strict | normal | rune:new | O2 | correctness | 1/1 | 43.750000000 | 43.750000000 to 43.750000000 | - |
| multiplier-strict | normal | rune:new | O2 | count | 1/1 | 40.580000000 | 40.580000000 to 40.580000000 | 2980927262/12841520112/374553042 |
| multiplier-strict | normal | rune:jit | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| multiplier-strict | normal | rune:jit | O2 | correctness | 1/1 | 23.830000000 | 23.830000000 to 23.830000000 | - |
| multiplier-strict | normal | rune:jit | O2 | count | 1/1 | 22.750000000 | 22.750000000 to 22.750000000 | 2980927262/12841520112/374553042 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

