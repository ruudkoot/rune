# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| linear-lazy | normal | rune | O2 | compile | 1/1 | 2.160000000 | 2.160000000 to 2.160000000 | - |
| linear-lazy | normal | rune | O2 | correctness | 1/1 | 88.540000000 | 88.540000000 to 88.540000000 | - |
| linear-lazy | normal | rune | O2 | count | 1/1 | 84.740000000 | 84.740000000 to 84.740000000 | 13884433355/26591141184/815133124 |
| linear-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.700000000 | 2.700000000 to 2.700000000 | - |
| linear-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.780000000 | 0.780000000 to 0.780000000 | - |
| linear-lazy | normal | rune:opt | O2 | correctness | 1/1 | 50.700000000 | 50.700000000 to 50.700000000 | - |
| linear-lazy | normal | rune:opt | O2 | count | 1/1 | 49.560000000 | 49.560000000 to 49.560000000 | 13884433355/26591141184/815133124 |
| linear-lazy | normal | rune:new | O2 | compile | 1/1 | 2.740000000 | 2.740000000 to 2.740000000 | - |
| linear-lazy | normal | rune:new | O2 | correctness | 1/1 | 97.300000000 | 97.300000000 to 97.300000000 | - |
| linear-lazy | normal | rune:new | O2 | count | 1/1 | 79.660000000 | 79.660000000 to 79.660000000 | 8365497125/26591141184/815133124 |
| linear-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| linear-lazy | normal | rune:jit | O2 | correctness | 1/1 | 34.170000000 | 34.170000000 to 34.170000000 | - |
| linear-lazy | normal | rune:jit | O2 | count | 1/1 | 34.680000000 | 34.680000000 to 34.680000000 | 8365497125/26591141184/815133124 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

