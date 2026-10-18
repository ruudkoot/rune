# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| comp_lab_nozift-lazy | normal | rune | O2 | compile | 1/1 | 2.770000000 | 2.770000000 to 2.770000000 | - |
| comp_lab_nozift-lazy | normal | rune | O2 | correctness | 1/1 | 53.580000000 | 53.580000000 to 53.580000000 | - |
| comp_lab_nozift-lazy | normal | rune | O2 | count | 1/1 | 50.450000000 | 50.450000000 to 50.450000000 | 4882903558/13437960184/424135805 |
| comp_lab_nozift-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.960000000 | 2.960000000 to 2.960000000 | - |
| comp_lab_nozift-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.810000000 | 0.810000000 to 0.810000000 | - |
| comp_lab_nozift-lazy | normal | rune:opt | O2 | correctness | 1/1 | 28.980000000 | 28.980000000 to 28.980000000 | - |
| comp_lab_nozift-lazy | normal | rune:opt | O2 | count | 1/1 | 26.890000000 | 26.890000000 to 26.890000000 | 4882903558/13437960184/424135805 |
| comp_lab_nozift-lazy | normal | rune:new | O2 | compile | 1/1 | 3.470000000 | 3.470000000 to 3.470000000 | - |
| comp_lab_nozift-lazy | normal | rune:new | O2 | correctness | 1/1 | 49.680000000 | 49.680000000 to 49.680000000 | - |
| comp_lab_nozift-lazy | normal | rune:new | O2 | count | 1/1 | 48.700000000 | 48.700000000 to 48.700000000 | 2867717931/13437960184/424135805 |
| comp_lab_nozift-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.720000000 | 2.720000000 to 2.720000000 | - |
| comp_lab_nozift-lazy | normal | rune:jit | O2 | correctness | 1/1 | 22.120000000 | 22.120000000 to 22.120000000 | - |
| comp_lab_nozift-lazy | normal | rune:jit | O2 | count | 1/1 | 21.090000000 | 21.090000000 to 21.090000000 | 2867717931/13437960184/424135805 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

