# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| parstof-lazy | normal | rune | O2 | compile | 1/1 | 3.790000000 | 3.790000000 to 3.790000000 | - |
| parstof-lazy | normal | rune | O2 | correctness | 1/1 | 32.230000000 | 32.230000000 to 32.230000000 | - |
| parstof-lazy | normal | rune | O2 | count | 1/1 | 28.000000000 | 28.000000000 to 28.000000000 | 3302024849/4600391000/135658191 |
| parstof-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.770000000 | 3.770000000 to 3.770000000 | - |
| parstof-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.990000000 | 0.990000000 to 0.990000000 | - |
| parstof-lazy | normal | rune:opt | O2 | correctness | 1/1 | 15.150000000 | 15.150000000 to 15.150000000 | - |
| parstof-lazy | normal | rune:opt | O2 | count | 1/1 | 12.880000000 | 12.880000000 to 12.880000000 | 3302024849/4600391000/135658191 |
| parstof-lazy | normal | rune:new | O2 | compile | 1/1 | 3.180000000 | 3.180000000 to 3.180000000 | - |
| parstof-lazy | normal | rune:new | O2 | correctness | 1/1 | 26.680000000 | 26.680000000 to 26.680000000 | - |
| parstof-lazy | normal | rune:new | O2 | count | 1/1 | 29.600000000 | 29.600000000 to 29.600000000 | 1880732386/4600391000/135658191 |
| parstof-lazy | normal | rune:jit | O2 | compile | 1/1 | 4.190000000 | 4.190000000 to 4.190000000 | - |
| parstof-lazy | normal | rune:jit | O2 | correctness | 1/1 | 13.950000000 | 13.950000000 to 13.950000000 | - |
| parstof-lazy | normal | rune:jit | O2 | count | 1/1 | 14.130000000 | 14.130000000 to 14.130000000 | 1880732386/4600391000/135658191 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

