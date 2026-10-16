# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| exact-reals-strict | normal | rune | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| exact-reals-strict | normal | rune | O2 | correctness | 1/1 | 63.220000000 | 63.220000000 to 63.220000000 | - |
| exact-reals-strict | normal | rune | O2 | count | 1/1 | 60.150000000 | 60.150000000 to 60.150000000 | 15250722423/16020570160/404949894 |
| exact-reals-strict | normal | rune:opt | O2 | compile | 1/1 | 1.690000000 | 1.690000000 to 1.690000000 | - |
| exact-reals-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| exact-reals-strict | normal | rune:opt | O2 | correctness | 1/1 | 26.640000000 | 26.640000000 to 26.640000000 | - |
| exact-reals-strict | normal | rune:opt | O2 | count | 1/1 | 27.200000000 | 27.200000000 to 27.200000000 | 15250722423/16020570160/404949894 |
| exact-reals-strict | normal | rune:new | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| exact-reals-strict | normal | rune:new | O2 | correctness | 1/1 | 58.160000000 | 58.160000000 to 58.160000000 | - |
| exact-reals-strict | normal | rune:new | O2 | count | 1/1 | 46.910000000 | 46.910000000 to 46.910000000 | 8699459083/16020570160/404949894 |
| exact-reals-strict | normal | rune:jit | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| exact-reals-strict | normal | rune:jit | O2 | correctness | 1/1 | 21.970000000 | 21.970000000 to 21.970000000 | - |
| exact-reals-strict | normal | rune:jit | O2 | count | 1/1 | 19.140000000 | 19.140000000 to 19.140000000 | 8699459083/16020570160/404949894 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

