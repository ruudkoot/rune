# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fulsom-strict | smoke | rune | O2 | compile | 1/1 | 2.580000000 | 2.580000000 to 2.580000000 | - |
| fulsom-strict | smoke | rune | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| fulsom-strict | smoke | rune | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 4958701/17427608/470153 |
| fulsom-strict | smoke | rune:opt | O2 | compile | 1/1 | 2.460000000 | 2.460000000 to 2.460000000 | - |
| fulsom-strict | smoke | rune:opt | O2 | native-compile | 1/1 | 0.660000000 | 0.660000000 to 0.660000000 | - |
| fulsom-strict | smoke | rune:opt | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| fulsom-strict | smoke | rune:opt | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 4958701/17427608/470153 |
| fulsom-strict | smoke | rune:new | O2 | compile | 1/1 | 2.710000000 | 2.710000000 to 2.710000000 | - |
| fulsom-strict | smoke | rune:new | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| fulsom-strict | smoke | rune:new | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 2901626/17427608/470153 |
| fulsom-strict | smoke | rune:jit | O2 | compile | 1/1 | 4.350000000 | 4.350000000 to 4.350000000 | - |
| fulsom-strict | smoke | rune:jit | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| fulsom-strict | smoke | rune:jit | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 2901626/17427608/470153 |
|  | smoke | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

