# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| kb_no_exc | normal | rune | O2 | compile | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |
| kb_no_exc | normal | rune | O2 | correctness | 1/1 | 29.970000000 | 29.970000000 to 29.970000000 | - |
| kb_no_exc | normal | rune | O2 | count | 1/1 | 26.400000000 | 26.400000000 to 26.400000000 | 6596260053/2799088376/73281703 |
| kb_no_exc | normal | rune:opt | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| kb_no_exc | normal | rune:opt | O2 | native-compile | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| kb_no_exc | normal | rune:opt | O2 | correctness | 1/1 | 9.700000000 | 9.700000000 to 9.700000000 | - |
| kb_no_exc | normal | rune:opt | O2 | count | 1/1 | 10.430000000 | 10.430000000 to 10.430000000 | 6596260053/2799088376/73281703 |
| kb_no_exc | normal | rune:new | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| kb_no_exc | normal | rune:new | O2 | correctness | 1/1 | 28.370000000 | 28.370000000 to 28.370000000 | - |
| kb_no_exc | normal | rune:new | O2 | count | 1/1 | 35.480000000 | 35.480000000 to 35.480000000 | 3071631302/2799088376/73281703 |
| kb_no_exc | normal | rune:jit | O2 | compile | 1/1 | 2.480000000 | 2.480000000 to 2.480000000 | - |
| kb_no_exc | normal | rune:jit | O2 | correctness | 1/1 | 11.520000000 | 11.520000000 to 11.520000000 | - |
| kb_no_exc | normal | rune:jit | O2 | count | 1/1 | 9.810000000 | 9.810000000 to 9.810000000 | 3071631302/2799088376/73281703 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

