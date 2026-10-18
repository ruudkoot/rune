# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lift-lazy | normal | rune | O2 | compile | 1/1 | 2.980000000 | 2.980000000 to 2.980000000 | - |
| lift-lazy | normal | rune | O2 | correctness | 1/1 | 15.800000000 | 15.800000000 to 15.800000000 | - |
| lift-lazy | normal | rune | O2 | count | 1/1 | 17.100000000 | 17.100000000 to 17.100000000 | 1423222959/5334402024/127745823 |
| lift-lazy | normal | rune:opt | O2 | compile | 1/1 | 4.840000000 | 4.840000000 to 4.840000000 | - |
| lift-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| lift-lazy | normal | rune:opt | O2 | correctness | 1/1 | 7.740000000 | 7.740000000 to 7.740000000 | - |
| lift-lazy | normal | rune:opt | O2 | count | 1/1 | 7.170000000 | 7.170000000 to 7.170000000 | 1423222959/5334402024/127745823 |
| lift-lazy | normal | rune:new | O2 | compile | 1/1 | 4.650000000 | 4.650000000 to 4.650000000 | - |
| lift-lazy | normal | rune:new | O2 | correctness | 1/1 | 15.890000000 | 15.890000000 to 15.890000000 | - |
| lift-lazy | normal | rune:new | O2 | count | 1/1 | 14.720000000 | 14.720000000 to 14.720000000 | 864950142/5334402024/127745823 |
| lift-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.970000000 | 2.970000000 to 2.970000000 | - |
| lift-lazy | normal | rune:jit | O2 | correctness | 1/1 | 6.620000000 | 6.620000000 to 6.620000000 | - |
| lift-lazy | normal | rune:jit | O2 | count | 1/1 | 6.920000000 | 6.920000000 to 6.920000000 | 864950142/5334402024/127745823 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

