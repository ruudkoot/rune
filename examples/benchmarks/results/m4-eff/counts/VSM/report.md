# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| VSM | normal | rune | O2 | compile | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | - |
| VSM | normal | rune | O2 | correctness | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | - |
| VSM | normal | rune | O2 | count | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | 97010475/536019184/11000506 |
| VSM | normal | rune:opt | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| VSM | normal | rune:opt | O2 | native-compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| VSM | normal | rune:opt | O2 | correctness | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| VSM | normal | rune:opt | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 97010475/536019184/11000506 |
| VSM | normal | rune:new | O2 | compile | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| VSM | normal | rune:new | O2 | correctness | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| VSM | normal | rune:new | O2 | count | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | 63006354/536019184/11000506 |
| VSM | normal | rune:jit | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| VSM | normal | rune:jit | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| VSM | normal | rune:jit | O2 | count | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | 63006354/536019184/11000506 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

