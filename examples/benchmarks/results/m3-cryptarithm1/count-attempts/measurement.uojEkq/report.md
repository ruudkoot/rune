# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| cryptarithm1-strict | normal | rune | O2 | compile | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| cryptarithm1-strict | normal | rune | O2 | correctness | 1/1 | 33.760000000 | 33.760000000 to 33.760000000 | - |
| cryptarithm1-strict | normal | rune | O2 | count | 1/1 | 40.170000000 | 40.170000000 to 40.170000000 | 4534143881/10984617568/274615474 |
| cryptarithm1-strict | normal | rune:opt | O2 | compile | 1/1 | 1.560000000 | 1.560000000 to 1.560000000 | - |
| cryptarithm1-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| cryptarithm1-strict | normal | rune:opt | O2 | correctness | 1/1 | 20.860000000 | 20.860000000 to 20.860000000 | - |
| cryptarithm1-strict | normal | rune:opt | O2 | count | 1/1 | 25.840000000 | 25.840000000 to 25.840000000 | 4534143881/10984617568/274615474 |
| cryptarithm1-strict | normal | rune:new | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| cryptarithm1-strict | normal | rune:new | O2 | correctness | 1/1 | 40.900000000 | 40.900000000 to 40.900000000 | - |
| cryptarithm1-strict | normal | rune:new | O2 | count | 1/1 | 41.430000000 | 41.430000000 to 41.430000000 | 2515085577/10984617568/274615474 |
| cryptarithm1-strict | normal | rune:jit | O2 | compile | 1/1 | 1.380000000 | 1.380000000 to 1.380000000 | - |
| cryptarithm1-strict | normal | rune:jit | O2 | correctness | 1/1 | 23.900000000 | 23.900000000 to 23.900000000 | - |
| cryptarithm1-strict | normal | rune:jit | O2 | count | 1/1 | 25.960000000 | 25.960000000 to 25.960000000 | 2515085577/10984617568/274615474 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

