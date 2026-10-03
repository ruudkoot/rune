# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| rec_seq_motzkin | normal | rune | O2 | compile | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | - |
| rec_seq_motzkin | normal | rune | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| rec_seq_motzkin | normal | rune | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 14349421/6482432/162086 |
| rec_seq_motzkin | normal | rune:opt | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| rec_seq_motzkin | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| rec_seq_motzkin | normal | rune:opt | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| rec_seq_motzkin | normal | rune:opt | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 14349421/6482432/162086 |
| rec_seq_motzkin | normal | rune:new | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| rec_seq_motzkin | normal | rune:new | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| rec_seq_motzkin | normal | rune:new | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 9648312/6482432/162086 |
| rec_seq_motzkin | normal | rune:jit | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| rec_seq_motzkin | normal | rune:jit | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| rec_seq_motzkin | normal | rune:jit | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 9648312/6482432/162086 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

