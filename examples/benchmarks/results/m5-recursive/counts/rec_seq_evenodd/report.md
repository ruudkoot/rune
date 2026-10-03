# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| rec_seq_evenodd | normal | rune | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| rec_seq_evenodd | normal | rune | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| rec_seq_evenodd | normal | rune | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 3211305/20296/537 |
| rec_seq_evenodd | normal | rune:opt | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| rec_seq_evenodd | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| rec_seq_evenodd | normal | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| rec_seq_evenodd | normal | rune:opt | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 3211305/20296/537 |
| rec_seq_evenodd | normal | rune:new | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| rec_seq_evenodd | normal | rune:new | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| rec_seq_evenodd | normal | rune:new | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 2064007/20296/537 |
| rec_seq_evenodd | normal | rune:jit | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| rec_seq_evenodd | normal | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| rec_seq_evenodd | normal | rune:jit | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 2064007/20296/537 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

