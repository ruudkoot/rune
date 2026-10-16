# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| smallpt | normal | rune | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| smallpt | normal | rune | O2 | correctness | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| smallpt | normal | rune | O2 | count | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | 288537317/221726608/4179492 |
| smallpt | normal | rune:opt | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| smallpt | normal | rune:opt | O2 | native-compile | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| smallpt | normal | rune:opt | O2 | correctness | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| smallpt | normal | rune:opt | O2 | count | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | 288537317/221726608/4179492 |
| smallpt | normal | rune:new | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| smallpt | normal | rune:new | O2 | correctness | 1/1 | 0.870000000 | 0.870000000 to 0.870000000 | - |
| smallpt | normal | rune:new | O2 | count | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | 129460863/221726608/4179492 |
| smallpt | normal | rune:jit | O2 | compile | 1/1 | 1.540000000 | 1.540000000 to 1.540000000 | - |
| smallpt | normal | rune:jit | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| smallpt | normal | rune:jit | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 129460863/221726608/4179492 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

