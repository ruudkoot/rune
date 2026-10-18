# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| comp_lab_zift-strict | normal | rune | O2 | compile | 1/1 | 2.690000000 | 2.690000000 to 2.690000000 | - |
| comp_lab_zift-strict | normal | rune | O2 | correctness | 1/1 | 17.870000000 | 17.870000000 to 17.870000000 | - |
| comp_lab_zift-strict | normal | rune | O2 | count | 1/1 | 16.210000000 | 16.210000000 to 16.210000000 | 1881929856/4941525696/141602264 |
| comp_lab_zift-strict | normal | rune:opt | O2 | compile | 1/1 | 2.900000000 | 2.900000000 to 2.900000000 | - |
| comp_lab_zift-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| comp_lab_zift-strict | normal | rune:opt | O2 | correctness | 1/1 | 5.660000000 | 5.660000000 to 5.660000000 | - |
| comp_lab_zift-strict | normal | rune:opt | O2 | count | 1/1 | 5.850000000 | 5.850000000 to 5.850000000 | 1881929856/4941525696/141602264 |
| comp_lab_zift-strict | normal | rune:new | O2 | compile | 1/1 | 2.480000000 | 2.480000000 to 2.480000000 | - |
| comp_lab_zift-strict | normal | rune:new | O2 | correctness | 1/1 | 15.830000000 | 15.830000000 to 15.830000000 | - |
| comp_lab_zift-strict | normal | rune:new | O2 | count | 1/1 | 15.660000000 | 15.660000000 to 15.660000000 | 1065277686/4941525696/141602264 |
| comp_lab_zift-strict | normal | rune:jit | O2 | compile | 1/1 | 2.740000000 | 2.740000000 to 2.740000000 | - |
| comp_lab_zift-strict | normal | rune:jit | O2 | correctness | 1/1 | 6.930000000 | 6.930000000 to 6.930000000 | - |
| comp_lab_zift-strict | normal | rune:jit | O2 | count | 1/1 | 6.000000000 | 6.000000000 to 6.000000000 | 1065277686/4941525696/141602264 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

