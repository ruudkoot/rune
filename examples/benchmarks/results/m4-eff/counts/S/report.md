# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| S | normal | rune | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| S | normal | rune | O2 | correctness | 1/1 | 0.820000000 | 0.820000000 to 0.820000000 | - |
| S | normal | rune | O2 | count | 1/1 | 0.690000000 | 0.690000000 to 0.690000000 | 28010285/184018920/5000499 |
| S | normal | rune:opt | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| S | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| S | normal | rune:opt | O2 | correctness | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| S | normal | rune:opt | O2 | count | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | 28010285/184018920/5000499 |
| S | normal | rune:new | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| S | normal | rune:new | O2 | correctness | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| S | normal | rune:new | O2 | count | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | 20006223/184018920/5000499 |
| S | normal | rune:jit | O2 | compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| S | normal | rune:jit | O2 | correctness | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | - |
| S | normal | rune:jit | O2 | count | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | 20006223/184018920/5000499 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

