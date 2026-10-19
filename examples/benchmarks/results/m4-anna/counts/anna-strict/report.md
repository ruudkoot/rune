# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| anna-strict | normal | rune | O2 | compile | 1/1 | 7.130000000 | 7.130000000 to 7.130000000 | - |
| anna-strict | normal | rune | O2 | correctness | 1/1 | 19.250000000 | 19.250000000 to 19.250000000 | - |
| anna-strict | normal | rune | O2 | count | 1/1 | 16.300000000 | 16.300000000 to 16.300000000 | 3703688642/5550590448/142267754 |
| anna-strict | normal | rune:opt | O2 | compile | 1/1 | 10.770000000 | 10.770000000 to 10.770000000 | - |
| anna-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| anna-strict | normal | rune:opt | O2 | correctness | 1/1 | 7.290000000 | 7.290000000 to 7.290000000 | - |
| anna-strict | normal | rune:opt | O2 | count | 1/1 | 6.450000000 | 6.450000000 to 6.450000000 | 3703688642/5550590448/142267754 |
| anna-strict | normal | rune:new | O2 | compile | 1/1 | 7.770000000 | 7.770000000 to 7.770000000 | - |
| anna-strict | normal | rune:new | O2 | correctness | 1/1 | 16.680000000 | 16.680000000 to 16.680000000 | - |
| anna-strict | normal | rune:new | O2 | count | 1/1 | 14.540000000 | 14.540000000 to 14.540000000 | 1948472530/5550590448/142267754 |
| anna-strict | normal | rune:jit | O2 | compile | 1/1 | 7.450000000 | 7.450000000 to 7.450000000 | - |
| anna-strict | normal | rune:jit | O2 | correctness | 1/1 | 9.020000000 | 9.020000000 to 9.020000000 | - |
| anna-strict | normal | rune:jit | O2 | count | 1/1 | 7.450000000 | 7.450000000 to 7.450000000 | 1948472530/5550590448/142267754 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

