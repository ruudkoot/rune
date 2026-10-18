# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_concat | normal | rune | O2 | compile | 1/1 | 2.960000000 | 2.960000000 to 2.960000000 | - |
| string_concat | normal | rune | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| string_concat | normal | rune | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 13210700/10586176/280708 |
| string_concat | normal | rune:opt | O2 | compile | 1/1 | 2.640000000 | 2.640000000 to 2.640000000 | - |
| string_concat | normal | rune:opt | O2 | native-compile | 1/1 | 0.660000000 | 0.660000000 to 0.660000000 | - |
| string_concat | normal | rune:opt | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| string_concat | normal | rune:opt | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 13210700/10586176/280708 |
| string_concat | normal | rune:new | O2 | compile | 1/1 | 3.000000000 | 3.000000000 to 3.000000000 | - |
| string_concat | normal | rune:new | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| string_concat | normal | rune:new | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 8586608/10586176/280708 |
| string_concat | normal | rune:jit | O2 | compile | 1/1 | 3.020000000 | 3.020000000 to 3.020000000 | - |
| string_concat | normal | rune:jit | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| string_concat | normal | rune:jit | O2 | count | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | 8586608/10586176/280708 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

