# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| para-lazy | normal | rune | O2 | compile | 1/1 | 2.420000000 | 2.420000000 to 2.420000000 | - |
| para-lazy | normal | rune | O2 | correctness | 1/1 | 68.560000000 | 68.560000000 to 68.560000000 | - |
| para-lazy | normal | rune | O2 | count | 1/1 | 58.910000000 | 58.910000000 to 58.910000000 | 7696436940/18678174568/594663175 |
| para-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.420000000 | 2.420000000 to 2.420000000 | - |
| para-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | - |
| para-lazy | normal | rune:opt | O2 | correctness | 1/1 | 27.510000000 | 27.510000000 to 27.510000000 | - |
| para-lazy | normal | rune:opt | O2 | count | 1/1 | 23.180000000 | 23.180000000 to 23.180000000 | 7696436940/18678174568/594663175 |
| para-lazy | normal | rune:new | O2 | compile | 1/1 | 1.900000000 | 1.900000000 to 1.900000000 | - |
| para-lazy | normal | rune:new | O2 | correctness | 1/1 | 49.710000000 | 49.710000000 to 49.710000000 | - |
| para-lazy | normal | rune:new | O2 | count | 1/1 | 55.610000000 | 55.610000000 to 55.610000000 | 4595487461/18678174568/594663175 |
| para-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.710000000 | 1.710000000 to 1.710000000 | - |
| para-lazy | normal | rune:jit | O2 | correctness | 1/1 | 25.010000000 | 25.010000000 to 25.010000000 | - |
| para-lazy | normal | rune:jit | O2 | count | 1/1 | 23.230000000 | 23.230000000 to 23.230000000 | 4595487461/18678174568/594663175 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

