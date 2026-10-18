# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| int_replace2 | normal | rune | O2 | compile | 1/1 | 2.970000000 | 2.970000000 to 2.970000000 | - |
| int_replace2 | normal | rune | O2 | correctness | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| int_replace2 | normal | rune | O2 | count | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | 191315913/104530760/1009667 |
| int_replace2 | normal | rune:opt | O2 | compile | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| int_replace2 | normal | rune:opt | O2 | native-compile | 1/1 | 0.930000000 | 0.930000000 to 0.930000000 | - |
| int_replace2 | normal | rune:opt | O2 | correctness | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| int_replace2 | normal | rune:opt | O2 | count | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | 191315913/104530760/1009667 |
| int_replace2 | normal | rune:new | O2 | compile | 1/1 | 3.070000000 | 3.070000000 to 3.070000000 | - |
| int_replace2 | normal | rune:new | O2 | correctness | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| int_replace2 | normal | rune:new | O2 | count | 1/1 | 1.080000000 | 1.080000000 to 1.080000000 | 116804123/104530760/1009667 |
| int_replace2 | normal | rune:jit | O2 | compile | 1/1 | 3.000000000 | 3.000000000 to 3.000000000 | - |
| int_replace2 | normal | rune:jit | O2 | correctness | 1/1 | 0.520000000 | 0.520000000 to 0.520000000 | - |
| int_replace2 | normal | rune:jit | O2 | count | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | 116804123/104530760/1009667 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

