# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fulsom-nofib-strict | smoke | rune | O2 | compile | 1/1 | 2.810000000 | 2.810000000 to 2.810000000 | - |
| fulsom-nofib-strict | smoke | rune | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| fulsom-nofib-strict | smoke | rune | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 4973102/17435032/470355 |
| fulsom-nofib-strict | smoke | rune:opt | O2 | compile | 1/1 | 3.990000000 | 3.990000000 to 3.990000000 | - |
| fulsom-nofib-strict | smoke | rune:opt | O2 | native-compile | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | - |
| fulsom-nofib-strict | smoke | rune:opt | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| fulsom-nofib-strict | smoke | rune:opt | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 4973102/17435032/470355 |
| fulsom-nofib-strict | smoke | rune:new | O2 | compile | 1/1 | 2.540000000 | 2.540000000 to 2.540000000 | - |
| fulsom-nofib-strict | smoke | rune:new | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| fulsom-nofib-strict | smoke | rune:new | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 2910248/17435032/470355 |
| fulsom-nofib-strict | smoke | rune:jit | O2 | compile | 1/1 | 2.860000000 | 2.860000000 to 2.860000000 | - |
| fulsom-nofib-strict | smoke | rune:jit | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| fulsom-nofib-strict | smoke | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 2910248/17435032/470355 |
|  | smoke | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

