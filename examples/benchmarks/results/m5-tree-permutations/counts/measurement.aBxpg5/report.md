# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| binarytrees5 | normal | rune | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| binarytrees5 | normal | rune | O2 | correctness | 1/1 | 2.220000000 | 2.220000000 to 2.220000000 | - |
| binarytrees5 | normal | rune | O2 | count | 1/1 | 2.340000000 | 2.340000000 to 2.340000000 | 496382352/599463680/14986574 |
| binarytrees5 | normal | rune:opt | O2 | compile | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | - |
| binarytrees5 | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| binarytrees5 | normal | rune:opt | O2 | correctness | 1/1 | 0.840000000 | 0.840000000 to 0.840000000 | - |
| binarytrees5 | normal | rune:opt | O2 | count | 1/1 | 0.910000000 | 0.910000000 to 0.910000000 | 496382352/599463680/14986574 |
| binarytrees5 | normal | rune:new | O2 | compile | 1/1 | 1.030000000 | 1.030000000 to 1.030000000 | - |
| binarytrees5 | normal | rune:new | O2 | correctness | 1/1 | 1.830000000 | 1.830000000 to 1.830000000 | - |
| binarytrees5 | normal | rune:new | O2 | count | 1/1 | 3.040000000 | 3.040000000 to 3.040000000 | 300861697/599463680/14986574 |
| binarytrees5 | normal | rune:jit | O2 | compile | 1/1 | 1.030000000 | 1.030000000 to 1.030000000 | - |
| binarytrees5 | normal | rune:jit | O2 | correctness | 1/1 | 0.790000000 | 0.790000000 to 0.790000000 | - |
| binarytrees5 | normal | rune:jit | O2 | count | 1/1 | 0.750000000 | 0.750000000 to 0.750000000 | 300861697/599463680/14986574 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

