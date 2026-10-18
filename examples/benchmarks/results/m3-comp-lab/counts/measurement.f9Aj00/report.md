# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| comp_lab_nozift-strict | normal | rune | O2 | compile | 1/1 | 4.260000000 | 4.260000000 to 4.260000000 | - |
| comp_lab_nozift-strict | normal | rune | O2 | correctness | 1/1 | 14.260000000 | 14.260000000 to 14.260000000 | - |
| comp_lab_nozift-strict | normal | rune | O2 | count | 1/1 | 14.130000000 | 14.130000000 to 14.130000000 | 1881929788/4941525696/141602264 |
| comp_lab_nozift-strict | normal | rune:opt | O2 | compile | 1/1 | 4.510000000 | 4.510000000 to 4.510000000 | - |
| comp_lab_nozift-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.050000000 | 1.050000000 to 1.050000000 | - |
| comp_lab_nozift-strict | normal | rune:opt | O2 | correctness | 1/1 | 7.610000000 | 7.610000000 to 7.610000000 | - |
| comp_lab_nozift-strict | normal | rune:opt | O2 | count | 1/1 | 6.400000000 | 6.400000000 to 6.400000000 | 1881929788/4941525696/141602264 |
| comp_lab_nozift-strict | normal | rune:new | O2 | compile | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | - |
| comp_lab_nozift-strict | normal | rune:new | O2 | correctness | 1/1 | 18.370000000 | 18.370000000 to 18.370000000 | - |
| comp_lab_nozift-strict | normal | rune:new | O2 | count | 1/1 | 14.990000000 | 14.990000000 to 14.990000000 | 1065277608/4941525696/141602264 |
| comp_lab_nozift-strict | normal | rune:jit | O2 | compile | 1/1 | 2.470000000 | 2.470000000 to 2.470000000 | - |
| comp_lab_nozift-strict | normal | rune:jit | O2 | correctness | 1/1 | 5.990000000 | 5.990000000 to 5.990000000 | - |
| comp_lab_nozift-strict | normal | rune:jit | O2 | count | 1/1 | 7.850000000 | 7.850000000 to 7.850000000 | 1065277608/4941525696/141602264 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

