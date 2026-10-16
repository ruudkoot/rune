# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| exact-reals-lazy | normal | rune | O2 | compile | 1/1 | 1.900000000 | 1.900000000 to 1.900000000 | - |
| exact-reals-lazy | normal | rune | O2 | correctness | 1/1 | 54.150000000 | 54.150000000 to 54.150000000 | - |
| exact-reals-lazy | normal | rune | O2 | count | 1/1 | 49.730000000 | 49.730000000 to 49.730000000 | 12711790362/13359272512/336770664 |
| exact-reals-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| exact-reals-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| exact-reals-lazy | normal | rune:opt | O2 | correctness | 1/1 | 21.230000000 | 21.230000000 to 21.230000000 | - |
| exact-reals-lazy | normal | rune:opt | O2 | count | 1/1 | 19.160000000 | 19.160000000 to 19.160000000 | 12711790362/13359272512/336770664 |
| exact-reals-lazy | normal | rune:new | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| exact-reals-lazy | normal | rune:new | O2 | correctness | 1/1 | 39.900000000 | 39.900000000 to 39.900000000 | - |
| exact-reals-lazy | normal | rune:new | O2 | count | 1/1 | 43.880000000 | 43.880000000 to 43.880000000 | 7245704344/13359272512/336770664 |
| exact-reals-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| exact-reals-lazy | normal | rune:jit | O2 | correctness | 1/1 | 14.470000000 | 14.470000000 to 14.470000000 | - |
| exact-reals-lazy | normal | rune:jit | O2 | count | 1/1 | 17.350000000 | 17.350000000 to 17.350000000 | 7245704344/13359272512/336770664 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

