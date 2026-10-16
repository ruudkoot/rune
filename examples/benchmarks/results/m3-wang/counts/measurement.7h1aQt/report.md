# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| wang-lazy | normal | rune | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| wang-lazy | normal | rune | O2 | correctness | 1/1 | 37.490000000 | 37.490000000 to 37.490000000 | - |
| wang-lazy | normal | rune | O2 | count | 1/1 | 34.560000000 | 34.560000000 to 34.560000000 | 6412017932/17984805000/541171563 |
| wang-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| wang-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| wang-lazy | normal | rune:opt | O2 | correctness | 1/1 | 18.660000000 | 18.660000000 to 18.660000000 | - |
| wang-lazy | normal | rune:opt | O2 | count | 1/1 | 18.560000000 | 18.560000000 to 18.560000000 | 6412017932/17984805000/541171563 |
| wang-lazy | normal | rune:new | O2 | compile | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | - |
| wang-lazy | normal | rune:new | O2 | correctness | 1/1 | 35.050000000 | 35.050000000 to 35.050000000 | - |
| wang-lazy | normal | rune:new | O2 | count | 1/1 | 35.260000000 | 35.260000000 to 35.260000000 | 3971995166/17984805000/541171563 |
| wang-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| wang-lazy | normal | rune:jit | O2 | correctness | 1/1 | 19.330000000 | 19.330000000 to 19.330000000 | - |
| wang-lazy | normal | rune:jit | O2 | count | 1/1 | 16.620000000 | 16.620000000 to 16.620000000 | 3971995166/17984805000/541171563 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

