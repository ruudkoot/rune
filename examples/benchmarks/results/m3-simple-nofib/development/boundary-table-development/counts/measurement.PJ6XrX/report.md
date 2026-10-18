# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-strict | normal | rune | O2 | compile | 1/1 | 6.270000000 | 6.270000000 to 6.270000000 | - |
| simple-nofib-strict | normal | rune | O2 | correctness | 1/1 | 81.600000000 | 81.600000000 to 81.600000000 | - |
| simple-nofib-strict | normal | rune | O2 | count | 1/1 | 97.300000000 | 97.300000000 to 97.300000000 | 6609268423/6758383144/166121603 |
| simple-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 9.020000000 | 9.020000000 to 9.020000000 | - |
| simple-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 3.650000000 | 3.650000000 to 3.650000000 | - |
| simple-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 41.800000000 | 41.800000000 to 41.800000000 | - |
| simple-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 37.280000000 | 37.280000000 to 37.280000000 | 6609268423/6758383144/166121603 |
| simple-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 7.680000000 | 7.680000000 to 7.680000000 | - |
| simple-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 88.580000000 | 88.580000000 to 88.580000000 | - |
| simple-nofib-strict | normal | rune:new | O2 | count | 1/1 | 94.670000000 | 94.670000000 to 94.670000000 | 3450595617/6758383144/166121603 |
| simple-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 9.030000000 | 9.030000000 to 9.030000000 | - |
| simple-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 28.810000000 | 28.810000000 to 28.810000000 | - |
| simple-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 25.720000000 | 25.720000000 to 25.720000000 | 3450595617/6758383144/166121603 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

