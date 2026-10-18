# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| map_iter | normal | rune | O2 | compile | 1/1 | 4.360000000 | 4.360000000 to 4.360000000 | - |
| map_iter | normal | rune | O2 | correctness | 1/1 | 10.780000000 | 10.780000000 to 10.780000000 | - |
| map_iter | normal | rune | O2 | count | 1/1 | 8.610000000 | 8.610000000 to 8.610000000 | 457692828/577845576/10319703 |
| map_iter | normal | rune:opt | O2 | compile | 1/1 | 4.810000000 | 4.810000000 to 4.810000000 | - |
| map_iter | normal | rune:opt | O2 | native-compile | 1/1 | 0.710000000 | 0.710000000 to 0.710000000 | - |
| map_iter | normal | rune:opt | O2 | correctness | 1/1 | 2.480000000 | 2.480000000 to 2.480000000 | - |
| map_iter | normal | rune:opt | O2 | count | 1/1 | 2.760000000 | 2.760000000 to 2.760000000 | 457692828/577845576/10319703 |
| map_iter | normal | rune:new | O2 | compile | 1/1 | 4.790000000 | 4.790000000 to 4.790000000 | - |
| map_iter | normal | rune:new | O2 | correctness | 1/1 | 7.570000000 | 7.570000000 to 7.570000000 | - |
| map_iter | normal | rune:new | O2 | count | 1/1 | 5.790000000 | 5.790000000 to 5.790000000 | 269202221/577845576/10319703 |
| map_iter | normal | rune:jit | O2 | compile | 1/1 | 5.040000000 | 5.040000000 to 5.040000000 | - |
| map_iter | normal | rune:jit | O2 | correctness | 1/1 | 3.090000000 | 3.090000000 to 3.090000000 | - |
| map_iter | normal | rune:jit | O2 | count | 1/1 | 2.780000000 | 2.780000000 to 2.780000000 | 269202221/577845576/10319703 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

