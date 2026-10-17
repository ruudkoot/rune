# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| prolog-strict | normal | rune | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| prolog-strict | normal | rune | O2 | correctness | 1/1 | 29.000000000 | 29.000000000 to 29.000000000 | - |
| prolog-strict | normal | rune | O2 | count | 1/1 | 29.970000000 | 29.970000000 to 29.970000000 | 5027570524/16963854104/507060741 |
| prolog-strict | normal | rune:opt | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| prolog-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | - |
| prolog-strict | normal | rune:opt | O2 | correctness | 1/1 | 15.270000000 | 15.270000000 to 15.270000000 | - |
| prolog-strict | normal | rune:opt | O2 | count | 1/1 | 12.860000000 | 12.860000000 to 12.860000000 | 5027570524/16963854104/507060741 |
| prolog-strict | normal | rune:new | O2 | compile | 1/1 | 2.080000000 | 2.080000000 to 2.080000000 | - |
| prolog-strict | normal | rune:new | O2 | correctness | 1/1 | 30.410000000 | 30.410000000 to 30.410000000 | - |
| prolog-strict | normal | rune:new | O2 | count | 1/1 | 31.320000000 | 31.320000000 to 31.320000000 | 2950462937/16963854104/507060741 |
| prolog-strict | normal | rune:jit | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| prolog-strict | normal | rune:jit | O2 | correctness | 1/1 | 13.090000000 | 13.090000000 to 13.090000000 | - |
| prolog-strict | normal | rune:jit | O2 | count | 1/1 | 15.920000000 | 15.920000000 to 15.920000000 | 2950462937/16963854104/507060741 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

