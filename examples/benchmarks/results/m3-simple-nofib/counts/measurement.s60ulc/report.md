# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-lazy | normal | rune | O2 | compile | 1/1 | 6.900000000 | 6.900000000 to 6.900000000 | - |
| simple-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 90.380000000 | 90.380000000 to 90.380000000 | - |
| simple-nofib-lazy | normal | rune | O2 | count | 1/1 | 115.050000000 | 115.050000000 to 115.050000000 | 6462101665/6499344000/161425188 |
| simple-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 8.040000000 | 8.040000000 to 8.040000000 | - |
| simple-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 2.270000000 | 2.270000000 to 2.270000000 | - |
| simple-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 47.110000000 | 47.110000000 to 47.110000000 | - |
| simple-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 44.260000000 | 44.260000000 to 44.260000000 | 6462101665/6499344000/161425188 |
| simple-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 8.420000000 | 8.420000000 to 8.420000000 | - |
| simple-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 92.960000000 | 92.960000000 to 92.960000000 | - |
| simple-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 93.700000000 | 93.700000000 to 93.700000000 | 3365263457/6499344000/161425188 |
| simple-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 5.730000000 | 5.730000000 to 5.730000000 | - |
| simple-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 26.900000000 | 26.900000000 to 26.900000000 | - |
| simple-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 21.560000000 | 21.560000000 to 21.560000000 | 3365263457/6499344000/161425188 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

