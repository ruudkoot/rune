# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_compare | normal | rune | O2 | compile | 1/1 | 3.340000000 | 3.340000000 to 3.340000000 | - |
| string_compare | normal | rune | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| string_compare | normal | rune | O2 | count | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | 24532553/29617848/740573 |
| string_compare | normal | rune:opt | O2 | compile | 1/1 | 2.750000000 | 2.750000000 to 2.750000000 | - |
| string_compare | normal | rune:opt | O2 | native-compile | 1/1 | 1.880000000 | 1.880000000 to 1.880000000 | - |
| string_compare | normal | rune:opt | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| string_compare | normal | rune:opt | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 24532553/29617848/740573 |
| string_compare | normal | rune:new | O2 | compile | 1/1 | 2.840000000 | 2.840000000 to 2.840000000 | - |
| string_compare | normal | rune:new | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| string_compare | normal | rune:new | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 12458784/29617848/740573 |
| string_compare | normal | rune:jit | O2 | compile | 1/1 | 2.670000000 | 2.670000000 to 2.670000000 | - |
| string_compare | normal | rune:jit | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| string_compare | normal | rune:jit | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 12458784/29617848/740573 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

