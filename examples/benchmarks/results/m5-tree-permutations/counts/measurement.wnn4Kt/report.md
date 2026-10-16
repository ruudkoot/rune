# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fannkuchredux | normal | rune | O2 | compile | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| fannkuchredux | normal | rune | O2 | correctness | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| fannkuchredux | normal | rune | O2 | count | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | 299383859/150345928/5537677 |
| fannkuchredux | normal | rune:opt | O2 | compile | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | - |
| fannkuchredux | normal | rune:opt | O2 | native-compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| fannkuchredux | normal | rune:opt | O2 | correctness | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| fannkuchredux | normal | rune:opt | O2 | count | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | 299383859/150345928/5537677 |
| fannkuchredux | normal | rune:new | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| fannkuchredux | normal | rune:new | O2 | correctness | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | - |
| fannkuchredux | normal | rune:new | O2 | count | 1/1 | 0.950000000 | 0.950000000 to 0.950000000 | 177601780/150345928/5537677 |
| fannkuchredux | normal | rune:jit | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| fannkuchredux | normal | rune:jit | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| fannkuchredux | normal | rune:jit | O2 | count | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | 177601780/150345928/5537677 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

