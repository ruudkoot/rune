# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| regexredux2 | normal | rune | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| regexredux2 | normal | rune | O2 | correctness | 1/1 | 5.490000000 | 5.490000000 to 5.490000000 | - |
| regexredux2 | normal | rune | O2 | count | 1/1 | 5.480000000 | 5.480000000 to 5.480000000 | 1554288238/130994216/2559765 |
| regexredux2 | normal | rune:opt | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| regexredux2 | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| regexredux2 | normal | rune:opt | O2 | correctness | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| regexredux2 | normal | rune:opt | O2 | count | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | 1554288238/130994216/2559765 |
| regexredux2 | normal | rune:new | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| regexredux2 | normal | rune:new | O2 | correctness | 1/1 | 4.720000000 | 4.720000000 to 4.720000000 | - |
| regexredux2 | normal | rune:new | O2 | count | 1/1 | 4.630000000 | 4.630000000 to 4.630000000 | 847310956/130994216/2559765 |
| regexredux2 | normal | rune:jit | O2 | compile | 1/1 | 2.380000000 | 2.380000000 to 2.380000000 | - |
| regexredux2 | normal | rune:jit | O2 | correctness | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |
| regexredux2 | normal | rune:jit | O2 | count | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | 847310956/130994216/2559765 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

