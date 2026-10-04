# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| stack_fold | normal | rune | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| stack_fold | normal | rune | O2 | correctness | 1/1 | 38.300000000 | 38.300000000 to 38.300000000 | - |
| stack_fold | normal | rune | O2 | count | 1/1 | 21.920000000 | 21.920000000 to 21.920000000 | 6657198653/10551519680/264788022 |
| stack_fold | normal | rune:opt | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| stack_fold | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| stack_fold | normal | rune:opt | O2 | correctness | 1/1 | 8.920000000 | 8.920000000 to 8.920000000 | - |
| stack_fold | normal | rune:opt | O2 | count | 1/1 | 10.300000000 | 10.300000000 to 10.300000000 | 6657198653/10551519680/264788022 |
| stack_fold | normal | rune:new | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| stack_fold | normal | rune:new | O2 | correctness | 1/1 | 17.330000000 | 17.330000000 to 17.330000000 | - |
| stack_fold | normal | rune:new | O2 | count | 1/1 | 17.140000000 | 17.140000000 to 17.140000000 | 2992244265/10551519680/264788022 |
| stack_fold | normal | rune:jit | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| stack_fold | normal | rune:jit | O2 | correctness | 1/1 | 5.770000000 | 5.770000000 to 5.770000000 | - |
| stack_fold | normal | rune:jit | O2 | count | 1/1 | 5.160000000 | 5.160000000 to 5.160000000 | 2992244265/10551519680/264788022 |
| stack_push_pop | normal | rune | O2 | compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| stack_push_pop | normal | rune | O2 | correctness | 1/1 | 200.740000000 | 200.740000000 to 200.740000000 | - |
| stack_push_pop | normal | rune | O2 | count | 1/1 | 227.040000000 | 227.040000000 to 227.040000000 | 52500011409/83200020392/2400000541 |
| stack_push_pop | normal | rune:opt | O2 | compile | 1/1 | 1.190000000 | 1.190000000 to 1.190000000 | - |
| stack_push_pop | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| stack_push_pop | normal | rune:opt | O2 | correctness | 1/1 | 90.010000000 | 90.010000000 to 90.010000000 | - |
| stack_push_pop | normal | rune:opt | O2 | count | 1/1 | 92.800000000 | 92.800000000 to 92.800000000 | 52500011409/83200020392/2400000541 |
| stack_push_pop | normal | rune:new | O2 | compile | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| stack_push_pop | normal | rune:new | O2 | correctness | 1/1 | 207.730000000 | 207.730000000 to 207.730000000 | - |
| stack_push_pop | normal | rune:new | O2 | count | 1/1 | 214.490000000 | 214.490000000 to 214.490000000 | 31200006931/83200020392/2400000541 |
| stack_push_pop | normal | rune:jit | O2 | compile | 1/1 | 1.950000000 | 1.950000000 to 1.950000000 | - |
| stack_push_pop | normal | rune:jit | O2 | correctness | 1/1 | 84.640000000 | 84.640000000 to 84.640000000 | - |
| stack_push_pop | normal | rune:jit | O2 | count | 1/1 | 83.290000000 | 83.290000000 to 83.290000000 | 31200006931/83200020392/2400000541 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

