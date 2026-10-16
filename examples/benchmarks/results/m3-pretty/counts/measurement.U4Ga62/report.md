# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| pretty-strict | normal | rune | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| pretty-strict | normal | rune | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| pretty-strict | normal | rune | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 87102/180040/4463 |
| pretty-strict | normal | rune:opt | O2 | compile | 1/1 | 1.920000000 | 1.920000000 to 1.920000000 | - |
| pretty-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| pretty-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| pretty-strict | normal | rune:opt | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 87102/180040/4463 |
| pretty-strict | normal | rune:new | O2 | compile | 1/1 | 1.860000000 | 1.860000000 to 1.860000000 | - |
| pretty-strict | normal | rune:new | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| pretty-strict | normal | rune:new | O2 | count | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | 50037/180040/4463 |
| pretty-strict | normal | rune:jit | O2 | compile | 1/1 | 1.930000000 | 1.930000000 to 1.930000000 | - |
| pretty-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| pretty-strict | normal | rune:jit | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 50037/180040/4463 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

