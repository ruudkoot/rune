# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| qr-decomposition | normal | rune | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| qr-decomposition | normal | rune | O2 | correctness | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| qr-decomposition | normal | rune | O2 | count | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | 279726359/555173096/13614989 |
| qr-decomposition | normal | rune:opt | O2 | compile | 1/1 | 1.540000000 | 1.540000000 to 1.540000000 | - |
| qr-decomposition | normal | rune:opt | O2 | native-compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| qr-decomposition | normal | rune:opt | O2 | correctness | 1/1 | 0.700000000 | 0.700000000 to 0.700000000 | - |
| qr-decomposition | normal | rune:opt | O2 | count | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | 279726359/555173096/13614989 |
| qr-decomposition | normal | rune:new | O2 | compile | 1/1 | 1.400000000 | 1.400000000 to 1.400000000 | - |
| qr-decomposition | normal | rune:new | O2 | correctness | 1/1 | 1.040000000 | 1.040000000 to 1.040000000 | - |
| qr-decomposition | normal | rune:new | O2 | count | 1/1 | 1.080000000 | 1.080000000 to 1.080000000 | 198566450/555173096/13614989 |
| qr-decomposition | normal | rune:jit | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| qr-decomposition | normal | rune:jit | O2 | correctness | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | - |
| qr-decomposition | normal | rune:jit | O2 | count | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | 198566450/555173096/13614989 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

