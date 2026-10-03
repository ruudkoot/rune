# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gc_bench | normal | rune | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| gc_bench | normal | rune | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| gc_bench | normal | rune | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 15985709/22119744/546668 |
| gc_bench | normal | rune:opt | O2 | compile | 1/1 | 1.550000000 | 1.550000000 to 1.550000000 | - |
| gc_bench | normal | rune:opt | O2 | native-compile | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| gc_bench | normal | rune:opt | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| gc_bench | normal | rune:opt | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 15985709/22119744/546668 |
| gc_bench | normal | rune:new | O2 | compile | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |
| gc_bench | normal | rune:new | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| gc_bench | normal | rune:new | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 9798901/22119744/546668 |
| gc_bench | normal | rune:jit | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| gc_bench | normal | rune:jit | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| gc_bench | normal | rune:jit | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 9798901/22119744/546668 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

