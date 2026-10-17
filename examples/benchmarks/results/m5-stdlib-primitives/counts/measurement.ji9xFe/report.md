# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| array_iter | normal | rune | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| array_iter | normal | rune | O2 | correctness | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| array_iter | normal | rune | O2 | count | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | 260649148/400494176/10011592 |
| array_iter | normal | rune:opt | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| array_iter | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| array_iter | normal | rune:opt | O2 | correctness | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| array_iter | normal | rune:opt | O2 | count | 1/1 | 2.700000000 | 2.700000000 to 2.700000000 | 260649148/400494176/10011592 |
| array_iter | normal | rune:new | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| array_iter | normal | rune:new | O2 | correctness | 1/1 | 1.120000000 | 1.120000000 to 1.120000000 | - |
| array_iter | normal | rune:new | O2 | count | 1/1 | 1.040000000 | 1.040000000 to 1.040000000 | 170478402/400494176/10011592 |
| array_iter | normal | rune:jit | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| array_iter | normal | rune:jit | O2 | correctness | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| array_iter | normal | rune:jit | O2 | count | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | 170478402/400494176/10011592 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

