# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fem-strict | normal | rune | O2 | compile | 1/1 | 3.200000000 | 3.200000000 to 3.200000000 | - |
| fem-strict | normal | rune | O2 | correctness | 1/1 | 70.210000000 | 70.210000000 to 70.210000000 | - |
| fem-strict | normal | rune | O2 | count | 1/1 | 59.910000000 | 59.910000000 to 59.910000000 | 7613491370/30867674760/897134607 |
| fem-strict | normal | rune:opt | O2 | compile | 1/1 | 3.390000000 | 3.390000000 to 3.390000000 | - |
| fem-strict | normal | rune:opt | O2 | native-compile | 1/1 | 2.260000000 | 2.260000000 to 2.260000000 | - |
| fem-strict | normal | rune:opt | O2 | correctness | 1/1 | 25.840000000 | 25.840000000 to 25.840000000 | - |
| fem-strict | normal | rune:opt | O2 | count | 1/1 | 27.170000000 | 27.170000000 to 27.170000000 | 7613491370/30867674760/897134607 |
| fem-strict | normal | rune:new | O2 | compile | 1/1 | 3.250000000 | 3.250000000 to 3.250000000 | - |
| fem-strict | normal | rune:new | O2 | correctness | 1/1 | 62.650000000 | 62.650000000 to 62.650000000 | - |
| fem-strict | normal | rune:new | O2 | count | 1/1 | 40.580000000 | 40.580000000 to 40.580000000 | 4660872044/30867674760/897134607 |
| fem-strict | normal | rune:jit | O2 | compile | 1/1 | 1.780000000 | 1.780000000 to 1.780000000 | - |
| fem-strict | normal | rune:jit | O2 | correctness | 1/1 | 16.980000000 | 16.980000000 to 16.980000000 | - |
| fem-strict | normal | rune:jit | O2 | count | 1/1 | 15.600000000 | 15.600000000 to 15.600000000 | 4660872044/30867674760/897134607 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

