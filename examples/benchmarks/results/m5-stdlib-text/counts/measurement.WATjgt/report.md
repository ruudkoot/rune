# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_iter | normal | rune | O2 | compile | 1/1 | 2.690000000 | 2.690000000 to 2.690000000 | - |
| string_iter | normal | rune | O2 | correctness | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| string_iter | normal | rune | O2 | count | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | 27722529/202064/6706 |
| string_iter | normal | rune:opt | O2 | compile | 1/1 | 3.170000000 | 3.170000000 to 3.170000000 | - |
| string_iter | normal | rune:opt | O2 | native-compile | 1/1 | 0.750000000 | 0.750000000 to 0.750000000 | - |
| string_iter | normal | rune:opt | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| string_iter | normal | rune:opt | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 27722529/202064/6706 |
| string_iter | normal | rune:new | O2 | compile | 1/1 | 2.660000000 | 2.660000000 to 2.660000000 | - |
| string_iter | normal | rune:new | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| string_iter | normal | rune:new | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 18480500/202064/6706 |
| string_iter | normal | rune:jit | O2 | compile | 1/1 | 4.360000000 | 4.360000000 to 4.360000000 | - |
| string_iter | normal | rune:jit | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| string_iter | normal | rune:jit | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 18480500/202064/6706 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

