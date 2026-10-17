# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| typecheck-strict | normal | rune | O2 | compile | 1/1 | 1.660000000 | 1.660000000 to 1.660000000 | - |
| typecheck-strict | normal | rune | O2 | correctness | 1/1 | 29.840000000 | 29.840000000 to 29.840000000 | - |
| typecheck-strict | normal | rune | O2 | count | 1/1 | 30.060000000 | 30.060000000 to 30.060000000 | 4497408858/14633640648/472307451 |
| typecheck-strict | normal | rune:opt | O2 | compile | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| typecheck-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| typecheck-strict | normal | rune:opt | O2 | correctness | 1/1 | 17.690000000 | 17.690000000 to 17.690000000 | - |
| typecheck-strict | normal | rune:opt | O2 | count | 1/1 | 18.680000000 | 18.680000000 to 18.680000000 | 4497408858/14633640648/472307451 |
| typecheck-strict | normal | rune:new | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| typecheck-strict | normal | rune:new | O2 | correctness | 1/1 | 31.590000000 | 31.590000000 to 31.590000000 | - |
| typecheck-strict | normal | rune:new | O2 | count | 1/1 | 30.720000000 | 30.720000000 to 30.720000000 | 2656067749/14633640648/472307451 |
| typecheck-strict | normal | rune:jit | O2 | compile | 1/1 | 1.870000000 | 1.870000000 to 1.870000000 | - |
| typecheck-strict | normal | rune:jit | O2 | correctness | 1/1 | 16.900000000 | 16.900000000 to 16.900000000 | - |
| typecheck-strict | normal | rune:jit | O2 | count | 1/1 | 17.260000000 | 17.260000000 to 17.260000000 | 2656067749/14633640648/472307451 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

