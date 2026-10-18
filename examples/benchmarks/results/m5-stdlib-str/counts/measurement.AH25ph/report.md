# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| str_regexp | normal | rune | O2 | compile | 1/1 | 2.330000000 | 2.330000000 to 2.330000000 | - |
| str_regexp | normal | rune | O2 | correctness | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| str_regexp | normal | rune | O2 | count | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | 29650448/47860248/1300519 |
| str_regexp | normal | rune:opt | O2 | compile | 1/1 | 2.850000000 | 2.850000000 to 2.850000000 | - |
| str_regexp | normal | rune:opt | O2 | native-compile | 1/1 | 0.690000000 | 0.690000000 to 0.690000000 | - |
| str_regexp | normal | rune:opt | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| str_regexp | normal | rune:opt | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 29650448/47860248/1300519 |
| str_regexp | normal | rune:new | O2 | compile | 1/1 | 3.000000000 | 3.000000000 to 3.000000000 | - |
| str_regexp | normal | rune:new | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| str_regexp | normal | rune:new | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 17846368/47860248/1300519 |
| str_regexp | normal | rune:jit | O2 | compile | 1/1 | 2.670000000 | 2.670000000 to 2.670000000 | - |
| str_regexp | normal | rune:jit | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| str_regexp | normal | rune:jit | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 17846368/47860248/1300519 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

