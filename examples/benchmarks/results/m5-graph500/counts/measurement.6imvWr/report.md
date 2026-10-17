# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| graph500-gen | normal | rune | O2 | compile | 1/1 | 4.080000000 | 4.080000000 to 4.080000000 | - |
| graph500-gen | normal | rune | O2 | correctness | 1/1 | 3.390000000 | 3.390000000 to 3.390000000 | - |
| graph500-gen | normal | rune | O2 | count | 1/1 | 4.020000000 | 4.020000000 to 4.020000000 | 519284279/354665920/7771996 |
| graph500-gen | normal | rune:opt | O2 | compile | 1/1 | 3.510000000 | 3.510000000 to 3.510000000 | - |
| graph500-gen | normal | rune:opt | O2 | native-compile | 1/1 | 0.560000000 | 0.560000000 to 0.560000000 | - |
| graph500-gen | normal | rune:opt | O2 | correctness | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| graph500-gen | normal | rune:opt | O2 | count | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | 519284279/354665920/7771996 |
| graph500-gen | normal | rune:new | O2 | compile | 1/1 | 3.090000000 | 3.090000000 to 3.090000000 | - |
| graph500-gen | normal | rune:new | O2 | correctness | 1/1 | 2.620000000 | 2.620000000 to 2.620000000 | - |
| graph500-gen | normal | rune:new | O2 | count | 1/1 | 2.760000000 | 2.760000000 to 2.760000000 | 303505863/354665920/7771996 |
| graph500-gen | normal | rune:jit | O2 | compile | 1/1 | 2.930000000 | 2.930000000 to 2.930000000 | - |
| graph500-gen | normal | rune:jit | O2 | correctness | 1/1 | 0.950000000 | 0.950000000 to 0.950000000 | - |
| graph500-gen | normal | rune:jit | O2 | count | 1/1 | 1.120000000 | 1.120000000 to 1.120000000 | 303505863/354665920/7771996 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

