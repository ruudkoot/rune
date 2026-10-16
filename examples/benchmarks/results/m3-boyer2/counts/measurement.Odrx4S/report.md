# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| boyer2-lazy | normal | rune | O2 | compile | 1/1 | 1.720000000 | 1.720000000 to 1.720000000 | - |
| boyer2-lazy | normal | rune | O2 | correctness | 1/1 | 19.300000000 | 19.300000000 to 19.300000000 | - |
| boyer2-lazy | normal | rune | O2 | count | 1/1 | 20.850000000 | 20.850000000 to 20.850000000 | 3456751626/3187150984/93733769 |
| boyer2-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.400000000 | 1.400000000 to 1.400000000 | - |
| boyer2-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| boyer2-lazy | normal | rune:opt | O2 | correctness | 1/1 | 8.180000000 | 8.180000000 to 8.180000000 | - |
| boyer2-lazy | normal | rune:opt | O2 | count | 1/1 | 7.410000000 | 7.410000000 to 7.410000000 | 3456751626/3187150984/93733769 |
| boyer2-lazy | normal | rune:new | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| boyer2-lazy | normal | rune:new | O2 | correctness | 1/1 | 17.230000000 | 17.230000000 to 17.230000000 | - |
| boyer2-lazy | normal | rune:new | O2 | count | 1/1 | 15.730000000 | 15.730000000 to 15.730000000 | 1922061479/3187150984/93733769 |
| boyer2-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.650000000 | 1.650000000 to 1.650000000 | - |
| boyer2-lazy | normal | rune:jit | O2 | correctness | 1/1 | 9.690000000 | 9.690000000 to 9.690000000 | - |
| boyer2-lazy | normal | rune:jit | O2 | count | 1/1 | 5.730000000 | 5.730000000 to 5.730000000 | 1922061479/3187150984/93733769 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

