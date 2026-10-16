# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| pidigits5 | normal | rune | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| pidigits5 | normal | rune | O2 | correctness | 1/1 | 26.180000000 | 26.180000000 to 26.180000000 | - |
| pidigits5 | normal | rune | O2 | count | 1/1 | 24.870000000 | 24.870000000 to 24.870000000 | 5581335620/5997830320/149945654 |
| pidigits5 | normal | rune:opt | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| pidigits5 | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| pidigits5 | normal | rune:opt | O2 | correctness | 1/1 | 9.160000000 | 9.160000000 to 9.160000000 | - |
| pidigits5 | normal | rune:opt | O2 | count | 1/1 | 9.210000000 | 9.210000000 to 9.210000000 | 5581335620/5997830320/149945654 |
| pidigits5 | normal | rune:new | O2 | compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| pidigits5 | normal | rune:new | O2 | correctness | 1/1 | 17.260000000 | 17.260000000 to 17.260000000 | - |
| pidigits5 | normal | rune:new | O2 | count | 1/1 | 19.510000000 | 19.510000000 to 19.510000000 | 3132865964/5997830320/149945654 |
| pidigits5 | normal | rune:jit | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| pidigits5 | normal | rune:jit | O2 | correctness | 1/1 | 7.770000000 | 7.770000000 to 7.770000000 | - |
| pidigits5 | normal | rune:jit | O2 | count | 1/1 | 9.120000000 | 9.120000000 to 9.120000000 | 3132865964/5997830320/149945654 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

