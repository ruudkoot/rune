# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| crout-decomposition | normal | rune | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| crout-decomposition | normal | rune | O2 | correctness | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| crout-decomposition | normal | rune | O2 | count | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | 49140193/129855296/2872556 |
| crout-decomposition | normal | rune:opt | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| crout-decomposition | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| crout-decomposition | normal | rune:opt | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| crout-decomposition | normal | rune:opt | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 49140193/129855296/2872556 |
| crout-decomposition | normal | rune:new | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| crout-decomposition | normal | rune:new | O2 | correctness | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| crout-decomposition | normal | rune:new | O2 | count | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | 32993149/129855296/2872556 |
| crout-decomposition | normal | rune:jit | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| crout-decomposition | normal | rune:jit | O2 | correctness | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| crout-decomposition | normal | rune:jit | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 32993149/129855296/2872556 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

