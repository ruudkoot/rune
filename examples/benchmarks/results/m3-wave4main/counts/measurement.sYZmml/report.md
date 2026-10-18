# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| wave4main-lazy | normal | rune | O2 | compile | 1/1 | 2.530000000 | 2.530000000 to 2.530000000 | - |
| wave4main-lazy | normal | rune | O2 | correctness | 1/1 | 41.860000000 | 41.860000000 to 41.860000000 | - |
| wave4main-lazy | normal | rune | O2 | count | 1/1 | 39.230000000 | 39.230000000 to 39.230000000 | 5283571056/2695448216/67180739 |
| wave4main-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |
| wave4main-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.620000000 | 0.620000000 to 0.620000000 | - |
| wave4main-lazy | normal | rune:opt | O2 | correctness | 1/1 | 12.990000000 | 12.990000000 to 12.990000000 | - |
| wave4main-lazy | normal | rune:opt | O2 | count | 1/1 | 14.490000000 | 14.490000000 to 14.490000000 | 5283571056/2695448216/67180739 |
| wave4main-lazy | normal | rune:new | O2 | compile | 1/1 | 2.220000000 | 2.220000000 to 2.220000000 | - |
| wave4main-lazy | normal | rune:new | O2 | correctness | 1/1 | 35.520000000 | 35.520000000 to 35.520000000 | - |
| wave4main-lazy | normal | rune:new | O2 | count | 1/1 | 33.340000000 | 33.340000000 to 33.340000000 | 2718828185/2695448216/67180739 |
| wave4main-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.110000000 | 2.110000000 to 2.110000000 | - |
| wave4main-lazy | normal | rune:jit | O2 | correctness | 1/1 | 10.590000000 | 10.590000000 to 10.590000000 | - |
| wave4main-lazy | normal | rune:jit | O2 | count | 1/1 | 11.600000000 | 11.600000000 to 11.600000000 | 2718828185/2695448216/67180739 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

