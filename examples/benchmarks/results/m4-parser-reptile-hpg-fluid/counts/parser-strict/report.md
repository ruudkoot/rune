# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| parser-strict | normal | rune | O2 | compile | 1/1 | 3.290000000 | 3.290000000 to 3.290000000 | - |
| parser-strict | normal | rune | O2 | correctness | 1/1 | 54.200000000 | 54.200000000 to 54.200000000 | - |
| parser-strict | normal | rune | O2 | count | 1/1 | 51.890000000 | 51.890000000 to 51.890000000 | 7829368389/19309568920/508520381 |
| parser-strict | normal | rune:opt | O2 | compile | 1/1 | 3.350000000 | 3.350000000 to 3.350000000 | - |
| parser-strict | normal | rune:opt | O2 | native-compile | 1/1 | 3.160000000 | 3.160000000 to 3.160000000 | - |
| parser-strict | normal | rune:opt | O2 | correctness | 1/1 | 27.790000000 | 27.790000000 to 27.790000000 | - |
| parser-strict | normal | rune:opt | O2 | count | 1/1 | 28.130000000 | 28.130000000 to 28.130000000 | 7829368389/19309568920/508520381 |
| parser-strict | normal | rune:new | O2 | compile | 1/1 | 3.870000000 | 3.870000000 to 3.870000000 | - |
| parser-strict | normal | rune:new | O2 | correctness | 1/1 | 55.460000000 | 55.460000000 to 55.460000000 | - |
| parser-strict | normal | rune:new | O2 | count | 1/1 | 51.540000000 | 51.540000000 to 51.540000000 | 4682936725/19309568920/508520381 |
| parser-strict | normal | rune:jit | O2 | compile | 1/1 | 5.600000000 | 5.600000000 to 5.600000000 | - |
| parser-strict | normal | rune:jit | O2 | correctness | 1/1 | 23.740000000 | 23.740000000 to 23.740000000 | - |
| parser-strict | normal | rune:jit | O2 | count | 1/1 | 26.960000000 | 26.960000000 to 26.960000000 | 4682936725/19309568920/508520381 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

