# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| multiplier-count-lazy | normal | rune | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| multiplier-count-lazy | normal | rune | O2 | correctness | 1/1 | 14.610000000 | 14.610000000 to 14.610000000 | - |
| multiplier-count-lazy | normal | rune | O2 | count | 1/1 | 16.070000000 | 16.070000000 to 16.070000000 | 1798051172/5176370544/151144838 |
| multiplier-count-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.280000000 | 3.280000000 to 3.280000000 | - |
| multiplier-count-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.590000000 | 0.590000000 to 0.590000000 | - |
| multiplier-count-lazy | normal | rune:opt | O2 | correctness | 1/1 | 10.520000000 | 10.520000000 to 10.520000000 | - |
| multiplier-count-lazy | normal | rune:opt | O2 | count | 1/1 | 10.590000000 | 10.590000000 to 10.590000000 | 1798051172/5176370544/151144838 |
| multiplier-count-lazy | normal | rune:new | O2 | compile | 1/1 | 2.140000000 | 2.140000000 to 2.140000000 | - |
| multiplier-count-lazy | normal | rune:new | O2 | correctness | 1/1 | 13.960000000 | 13.960000000 to 13.960000000 | - |
| multiplier-count-lazy | normal | rune:new | O2 | count | 1/1 | 14.670000000 | 14.670000000 to 14.670000000 | 1085372803/5176370544/151144838 |
| multiplier-count-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.820000000 | 1.820000000 to 1.820000000 | - |
| multiplier-count-lazy | normal | rune:jit | O2 | correctness | 1/1 | 9.390000000 | 9.390000000 to 9.390000000 | - |
| multiplier-count-lazy | normal | rune:jit | O2 | count | 1/1 | 9.370000000 | 9.370000000 to 9.370000000 | 1085372803/5176370544/151144838 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

