# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| rec_seq_tak | normal | rune | O2 | compile | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| rec_seq_tak | normal | rune | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| rec_seq_tak | normal | rune | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 27438499/21216/562 |
| rec_seq_tak | normal | rune:opt | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| rec_seq_tak | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| rec_seq_tak | normal | rune:opt | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| rec_seq_tak | normal | rune:opt | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 27438499/21216/562 |
| rec_seq_tak | normal | rune:new | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| rec_seq_tak | normal | rune:new | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| rec_seq_tak | normal | rune:new | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 14967143/21216/562 |
| rec_seq_tak | normal | rune:jit | O2 | compile | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| rec_seq_tak | normal | rune:jit | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| rec_seq_tak | normal | rune:jit | O2 | count | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | 14967143/21216/562 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

