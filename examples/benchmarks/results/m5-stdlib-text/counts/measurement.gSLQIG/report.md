# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_trim | normal | rune | O2 | compile | 1/1 | 3.440000000 | 3.440000000 to 3.440000000 | - |
| bytes_trim | normal | rune | O2 | correctness | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| bytes_trim | normal | rune | O2 | count | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | 36724372/59099448/1381305 |
| bytes_trim | normal | rune:opt | O2 | compile | 1/1 | 3.080000000 | 3.080000000 to 3.080000000 | - |
| bytes_trim | normal | rune:opt | O2 | native-compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| bytes_trim | normal | rune:opt | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| bytes_trim | normal | rune:opt | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 36724372/59099448/1381305 |
| bytes_trim | normal | rune:new | O2 | compile | 1/1 | 3.360000000 | 3.360000000 to 3.360000000 | - |
| bytes_trim | normal | rune:new | O2 | correctness | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| bytes_trim | normal | rune:new | O2 | count | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | 25415534/59099448/1381305 |
| bytes_trim | normal | rune:jit | O2 | compile | 1/1 | 2.740000000 | 2.740000000 to 2.740000000 | - |
| bytes_trim | normal | rune:jit | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| bytes_trim | normal | rune:jit | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 25415534/59099448/1381305 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

