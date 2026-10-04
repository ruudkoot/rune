# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| scc-lazy | normal | rune | O2 | compile | 1/1 | 2.440000000 | 2.440000000 to 2.440000000 | - |
| scc-lazy | normal | rune | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| scc-lazy | normal | rune | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 35620/96504/2849 |
| scc-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.310000000 | 3.310000000 to 3.310000000 | - |
| scc-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.990000000 | 0.990000000 to 0.990000000 | - |
| scc-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| scc-lazy | normal | rune:opt | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 35620/96504/2849 |
| scc-lazy | normal | rune:new | O2 | compile | 1/1 | 9.190000000 | 9.190000000 to 9.190000000 | - |
| scc-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| scc-lazy | normal | rune:new | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 21107/96504/2849 |
| scc-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.160000000 | 2.160000000 to 2.160000000 | - |
| scc-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| scc-lazy | normal | rune:jit | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 21107/96504/2849 |
| scc-strict | normal | rune | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| scc-strict | normal | rune | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| scc-strict | normal | rune | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 20731/38096/974 |
| scc-strict | normal | rune:opt | O2 | compile | 1/1 | 1.780000000 | 1.780000000 to 1.780000000 | - |
| scc-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.960000000 | 0.960000000 to 0.960000000 | - |
| scc-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| scc-strict | normal | rune:opt | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 20731/38096/974 |
| scc-strict | normal | rune:new | O2 | compile | 1/1 | 3.550000000 | 3.550000000 to 3.550000000 | - |
| scc-strict | normal | rune:new | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| scc-strict | normal | rune:new | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 11685/38096/974 |
| scc-strict | normal | rune:jit | O2 | compile | 1/1 | 1.660000000 | 1.660000000 to 1.660000000 | - |
| scc-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| scc-strict | normal | rune:jit | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 11685/38096/974 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

