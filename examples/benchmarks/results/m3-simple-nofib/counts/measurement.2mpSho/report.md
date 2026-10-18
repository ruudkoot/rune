# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-strict | normal | rune | O2 | compile | 1/1 | 5.910000000 | 5.910000000 to 5.910000000 | - |
| simple-nofib-strict | normal | rune | O2 | correctness | 1/1 | 88.060000000 | 88.060000000 to 88.060000000 | - |
| simple-nofib-strict | normal | rune | O2 | count | 1/1 | 53.450000000 | 53.450000000 to 53.450000000 | 7829487509/11014329672/301969885 |
| simple-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 3.560000000 | 3.560000000 to 3.560000000 | - |
| simple-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.960000000 | 0.960000000 to 0.960000000 | - |
| simple-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 22.090000000 | 22.090000000 to 22.090000000 | - |
| simple-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 22.940000000 | 22.940000000 to 22.940000000 | 7829487509/11014329672/301969885 |
| simple-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 3.970000000 | 3.970000000 to 3.970000000 | - |
| simple-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 55.820000000 | 55.820000000 to 55.820000000 | - |
| simple-nofib-strict | normal | rune:new | O2 | count | 1/1 | 56.720000000 | 56.720000000 to 56.720000000 | 4249205798/11014329672/301969885 |
| simple-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 4.970000000 | 4.970000000 to 4.970000000 | - |
| simple-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 20.930000000 | 20.930000000 to 20.930000000 | - |
| simple-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 23.250000000 | 23.250000000 to 23.250000000 | 4249205798/11014329672/301969885 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

