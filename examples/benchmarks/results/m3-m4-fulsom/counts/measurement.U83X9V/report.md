# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fulsom-lazy | smoke | rune | O2 | compile | 1/1 | 2.750000000 | 2.750000000 to 2.750000000 | - |
| fulsom-lazy | smoke | rune | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| fulsom-lazy | smoke | rune | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 9789174/32003696/993360 |
| fulsom-lazy | smoke | rune:opt | O2 | compile | 1/1 | 3.420000000 | 3.420000000 to 3.420000000 | - |
| fulsom-lazy | smoke | rune:opt | O2 | native-compile | 1/1 | 0.860000000 | 0.860000000 to 0.860000000 | - |
| fulsom-lazy | smoke | rune:opt | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| fulsom-lazy | smoke | rune:opt | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 9789174/32003696/993360 |
| fulsom-lazy | smoke | rune:new | O2 | compile | 1/1 | 2.610000000 | 2.610000000 to 2.610000000 | - |
| fulsom-lazy | smoke | rune:new | O2 | correctness | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| fulsom-lazy | smoke | rune:new | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 5870557/32003696/993360 |
| fulsom-lazy | smoke | rune:jit | O2 | compile | 1/1 | 2.580000000 | 2.580000000 to 2.580000000 | - |
| fulsom-lazy | smoke | rune:jit | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| fulsom-lazy | smoke | rune:jit | O2 | count | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | 5870557/32003696/993360 |
|  | smoke | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

