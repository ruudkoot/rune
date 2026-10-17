# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| kronecker | normal | rune | O2 | compile | 1/1 | 2.650000000 | 2.650000000 to 2.650000000 | - |
| kronecker | normal | rune | O2 | correctness | 1/1 | 3.240000000 | 3.240000000 to 3.240000000 | - |
| kronecker | normal | rune | O2 | count | 1/1 | 3.470000000 | 3.470000000 to 3.470000000 | 615808189/1676615944/34996605 |
| kronecker | normal | rune:opt | O2 | compile | 1/1 | 2.300000000 | 2.300000000 to 2.300000000 | - |
| kronecker | normal | rune:opt | O2 | native-compile | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| kronecker | normal | rune:opt | O2 | correctness | 1/1 | 1.680000000 | 1.680000000 to 1.680000000 | - |
| kronecker | normal | rune:opt | O2 | count | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | 615808189/1676615944/34996605 |
| kronecker | normal | rune:new | O2 | compile | 1/1 | 2.500000000 | 2.500000000 to 2.500000000 | - |
| kronecker | normal | rune:new | O2 | correctness | 1/1 | 3.230000000 | 3.230000000 to 3.230000000 | - |
| kronecker | normal | rune:new | O2 | count | 1/1 | 3.260000000 | 3.260000000 to 3.260000000 | 404191667/1676615944/34996605 |
| kronecker | normal | rune:jit | O2 | compile | 1/1 | 2.210000000 | 2.210000000 to 2.210000000 | - |
| kronecker | normal | rune:jit | O2 | correctness | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| kronecker | normal | rune:jit | O2 | count | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | 404191667/1676615944/34996605 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

