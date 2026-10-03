# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| n-body | normal | rune | O2 | compile | 1/1 | 1.380000000 | 1.380000000 to 1.380000000 | - |
| n-body | normal | rune | O2 | correctness | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| n-body | normal | rune | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 40913817/56217224/1005779 |
| n-body | normal | rune:opt | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| n-body | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| n-body | normal | rune:opt | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| n-body | normal | rune:opt | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 40913817/56217224/1005779 |
| n-body | normal | rune:new | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| n-body | normal | rune:new | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| n-body | normal | rune:new | O2 | count | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | 16617578/56217224/1005779 |
| n-body | normal | rune:jit | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| n-body | normal | rune:jit | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| n-body | normal | rune:jit | O2 | count | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | 16617578/56217224/1005779 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

