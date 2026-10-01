# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| tak | smoke | rune | O0 | compile | 1/1 | 0.990000000 | 0.990000000 to 0.990000000 | - |
| tak | smoke | rune | O0 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| tak | smoke | rune | O0 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 1737455/3639424/65838 |
| tak | smoke | rune:opt | O0 | compile | 1/1 | 1.060000000 | 1.060000000 to 1.060000000 | - |
| tak | smoke | rune:opt | O0 | native-compile | 1/1 | 0.860000000 | 0.860000000 to 0.860000000 | - |
| tak | smoke | rune:opt | O0 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| tak | smoke | rune:opt | O0 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 1737455/3639424/65838 |
| tak | smoke | rune:new | O0 | compile | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |
| tak | smoke | rune:new | O0 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| tak | smoke | rune:new | O0 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 919002/3639424/65838 |
| tak | smoke | rune:jit | O0 | compile | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |
| tak | smoke | rune:jit | O0 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| tak | smoke | rune:jit | O0 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 919002/3639424/65838 |
|  | smoke | rune:jit | O0 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

