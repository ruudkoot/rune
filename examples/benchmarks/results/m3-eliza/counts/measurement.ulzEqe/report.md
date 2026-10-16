# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| eliza-strict | normal | rune | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| eliza-strict | normal | rune | O2 | correctness | 1/1 | 34.730000000 | 34.730000000 to 34.730000000 | - |
| eliza-strict | normal | rune | O2 | count | 1/1 | 32.690000000 | 32.690000000 to 32.690000000 | 7619213509/20199019560/524692391 |
| eliza-strict | normal | rune:opt | O2 | compile | 1/1 | 1.380000000 | 1.380000000 to 1.380000000 | - |
| eliza-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| eliza-strict | normal | rune:opt | O2 | correctness | 1/1 | 16.080000000 | 16.080000000 to 16.080000000 | - |
| eliza-strict | normal | rune:opt | O2 | count | 1/1 | 14.940000000 | 14.940000000 to 14.940000000 | 7619213509/20199019560/524692391 |
| eliza-strict | normal | rune:new | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| eliza-strict | normal | rune:new | O2 | correctness | 1/1 | 32.330000000 | 32.330000000 to 32.330000000 | - |
| eliza-strict | normal | rune:new | O2 | count | 1/1 | 32.950000000 | 32.950000000 to 32.950000000 | 4718168266/20199019560/524692391 |
| eliza-strict | normal | rune:jit | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| eliza-strict | normal | rune:jit | O2 | correctness | 1/1 | 12.820000000 | 12.820000000 to 12.820000000 | - |
| eliza-strict | normal | rune:jit | O2 | count | 1/1 | 16.370000000 | 16.370000000 to 16.370000000 | 4718168266/20199019560/524692391 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

