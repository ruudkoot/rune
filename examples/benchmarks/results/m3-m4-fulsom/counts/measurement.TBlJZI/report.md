# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fulsom-nofib-lazy | smoke | rune | O2 | compile | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| fulsom-nofib-lazy | smoke | rune | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| fulsom-nofib-lazy | smoke | rune | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 9803575/32011136/993562 |
| fulsom-nofib-lazy | smoke | rune:opt | O2 | compile | 1/1 | 2.920000000 | 2.920000000 to 2.920000000 | - |
| fulsom-nofib-lazy | smoke | rune:opt | O2 | native-compile | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | - |
| fulsom-nofib-lazy | smoke | rune:opt | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| fulsom-nofib-lazy | smoke | rune:opt | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 9803575/32011136/993562 |
| fulsom-nofib-lazy | smoke | rune:new | O2 | compile | 1/1 | 3.150000000 | 3.150000000 to 3.150000000 | - |
| fulsom-nofib-lazy | smoke | rune:new | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| fulsom-nofib-lazy | smoke | rune:new | O2 | count | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | 5879179/32011136/993562 |
| fulsom-nofib-lazy | smoke | rune:jit | O2 | compile | 1/1 | 3.590000000 | 3.590000000 to 3.590000000 | - |
| fulsom-nofib-lazy | smoke | rune:jit | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| fulsom-nofib-lazy | smoke | rune:jit | O2 | count | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | 5879179/32011136/993562 |
|  | smoke | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

