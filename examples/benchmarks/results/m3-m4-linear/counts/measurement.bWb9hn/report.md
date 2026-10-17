# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| linear-strict | normal | rune | O2 | compile | 1/1 | 2.030000000 | 2.030000000 to 2.030000000 | - |
| linear-strict | normal | rune | O2 | correctness | 1/1 | 61.380000000 | 61.380000000 to 61.380000000 | - |
| linear-strict | normal | rune | O2 | count | 1/1 | 61.450000000 | 61.450000000 to 61.450000000 | 12963131687/21693562232/660414331 |
| linear-strict | normal | rune:opt | O2 | compile | 1/1 | 1.990000000 | 1.990000000 to 1.990000000 | - |
| linear-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.520000000 | 0.520000000 to 0.520000000 | - |
| linear-strict | normal | rune:opt | O2 | correctness | 1/1 | 32.300000000 | 32.300000000 to 32.300000000 | - |
| linear-strict | normal | rune:opt | O2 | count | 1/1 | 31.610000000 | 31.610000000 to 31.610000000 | 12963131687/21693562232/660414331 |
| linear-strict | normal | rune:new | O2 | compile | 1/1 | 2.060000000 | 2.060000000 to 2.060000000 | - |
| linear-strict | normal | rune:new | O2 | correctness | 1/1 | 59.550000000 | 59.550000000 to 59.550000000 | - |
| linear-strict | normal | rune:new | O2 | count | 1/1 | 59.710000000 | 59.710000000 to 59.710000000 | 7767038921/21693562232/660414331 |
| linear-strict | normal | rune:jit | O2 | compile | 1/1 | 2.180000000 | 2.180000000 to 2.180000000 | - |
| linear-strict | normal | rune:jit | O2 | correctness | 1/1 | 30.120000000 | 30.120000000 to 30.120000000 | - |
| linear-strict | normal | rune:jit | O2 | count | 1/1 | 29.830000000 | 29.830000000 to 29.830000000 | 7767038921/21693562232/660414331 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

