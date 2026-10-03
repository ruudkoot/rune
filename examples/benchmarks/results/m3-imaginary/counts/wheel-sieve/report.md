# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| wheel-sieve1-lazy | normal | rune | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| wheel-sieve1-lazy | normal | rune | O2 | correctness | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| wheel-sieve1-lazy | normal | rune | O2 | count | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | 84878413/113620064/3161214 |
| wheel-sieve1-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.590000000 | 2.590000000 to 2.590000000 | - |
| wheel-sieve1-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | - |
| wheel-sieve1-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |
| wheel-sieve1-lazy | normal | rune:opt | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 84878413/113620064/3161214 |
| wheel-sieve1-lazy | normal | rune:new | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| wheel-sieve1-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| wheel-sieve1-lazy | normal | rune:new | O2 | count | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | 48679828/113620064/3161214 |
| wheel-sieve1-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| wheel-sieve1-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| wheel-sieve1-lazy | normal | rune:jit | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 48679828/113620064/3161214 |
| wheel-sieve2-lazy | normal | rune | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| wheel-sieve2-lazy | normal | rune | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| wheel-sieve2-lazy | normal | rune | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 44695583/84796312/2420539 |
| wheel-sieve2-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| wheel-sieve2-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| wheel-sieve2-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| wheel-sieve2-lazy | normal | rune:opt | O2 | count | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | 44695583/84796312/2420539 |
| wheel-sieve2-lazy | normal | rune:new | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| wheel-sieve2-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| wheel-sieve2-lazy | normal | rune:new | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 25809967/84796312/2420539 |
| wheel-sieve2-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| wheel-sieve2-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| wheel-sieve2-lazy | normal | rune:jit | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 25809967/84796312/2420539 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

