# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| comp_lab_zift-lazy | normal | rune | O2 | compile | 1/1 | 1.810000000 | 1.810000000 to 1.810000000 | - |
| comp_lab_zift-lazy | normal | rune | O2 | correctness | 1/1 | 30.780000000 | 30.780000000 to 30.780000000 | - |
| comp_lab_zift-lazy | normal | rune | O2 | count | 1/1 | 28.380000000 | 28.380000000 to 28.380000000 | 4882903626/13437960184/424135805 |
| comp_lab_zift-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| comp_lab_zift-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| comp_lab_zift-lazy | normal | rune:opt | O2 | correctness | 1/1 | 14.730000000 | 14.730000000 to 14.730000000 | - |
| comp_lab_zift-lazy | normal | rune:opt | O2 | count | 1/1 | 14.900000000 | 14.900000000 to 14.900000000 | 4882903626/13437960184/424135805 |
| comp_lab_zift-lazy | normal | rune:new | O2 | compile | 1/1 | 2.080000000 | 2.080000000 to 2.080000000 | - |
| comp_lab_zift-lazy | normal | rune:new | O2 | correctness | 1/1 | 42.330000000 | 42.330000000 to 42.330000000 | - |
| comp_lab_zift-lazy | normal | rune:new | O2 | count | 1/1 | 50.400000000 | 50.400000000 to 50.400000000 | 2867718009/13437960184/424135805 |
| comp_lab_zift-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.480000000 | 3.480000000 to 3.480000000 | - |
| comp_lab_zift-lazy | normal | rune:jit | O2 | correctness | 1/1 | 24.760000000 | 24.760000000 to 24.760000000 | - |
| comp_lab_zift-lazy | normal | rune:jit | O2 | count | 1/1 | 21.930000000 | 21.930000000 to 21.930000000 | 2867718009/13437960184/424135805 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

