# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| cryptarithm1-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| cryptarithm1-lazy | normal | rune:jit | O2 | correctness | 1/1 | 32.970000000 | 32.970000000 to 32.970000000 | - |
| cryptarithm1-lazy | normal | rune:jit | O2 | count | 1/1 | 33.690000000 | 33.690000000 to 33.690000000 | 8042092347/40937145272/1218529891 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

