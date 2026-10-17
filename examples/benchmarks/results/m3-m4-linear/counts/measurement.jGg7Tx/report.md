# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| linear-nofib-gc-lazy | normal | rune | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| linear-nofib-gc-lazy | normal | rune | O2 | correctness | 1/1 | 42.330000000 | 42.330000000 to 42.330000000 | - |
| linear-nofib-gc-lazy | normal | rune | O2 | count | 1/1 | 42.190000000 | 42.190000000 to 42.190000000 | 7767317907/10560268648/323740473 |
| linear-nofib-gc-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.900000000 | 1.900000000 to 1.900000000 | - |
| linear-nofib-gc-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | - |
| linear-nofib-gc-lazy | normal | rune:opt | O2 | correctness | 1/1 | 23.830000000 | 23.830000000 to 23.830000000 | - |
| linear-nofib-gc-lazy | normal | rune:opt | O2 | count | 1/1 | 24.420000000 | 24.420000000 to 24.420000000 | 7767317907/10560268648/323740473 |
| linear-nofib-gc-lazy | normal | rune:new | O2 | compile | 1/1 | 1.950000000 | 1.950000000 to 1.950000000 | - |
| linear-nofib-gc-lazy | normal | rune:new | O2 | correctness | 1/1 | 41.340000000 | 41.340000000 to 41.340000000 | - |
| linear-nofib-gc-lazy | normal | rune:new | O2 | count | 1/1 | 39.770000000 | 39.770000000 to 39.770000000 | 4690833637/10560268648/323740473 |
| linear-nofib-gc-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.140000000 | 2.140000000 to 2.140000000 | - |
| linear-nofib-gc-lazy | normal | rune:jit | O2 | correctness | 1/1 | 24.550000000 | 24.550000000 to 24.550000000 | - |
| linear-nofib-gc-lazy | normal | rune:jit | O2 | count | 1/1 | 25.070000000 | 25.070000000 to 25.070000000 | 4690833637/10560268648/323740473 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

