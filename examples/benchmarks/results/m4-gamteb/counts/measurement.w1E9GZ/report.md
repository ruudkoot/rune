# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gamteb-strict | normal | rune | O2 | compile | 1/1 | 1.860000000 | 1.860000000 to 1.860000000 | - |
| gamteb-strict | normal | rune | O2 | correctness | 1/1 | 18.510000000 | 18.510000000 to 18.510000000 | - |
| gamteb-strict | normal | rune | O2 | count | 1/1 | 16.130000000 | 16.130000000 to 16.130000000 | 2779187057/5658662600/154663193 |
| gamteb-strict | normal | rune:opt | O2 | compile | 1/1 | 1.650000000 | 1.650000000 to 1.650000000 | - |
| gamteb-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| gamteb-strict | normal | rune:opt | O2 | correctness | 1/1 | 6.760000000 | 6.760000000 to 6.760000000 | - |
| gamteb-strict | normal | rune:opt | O2 | count | 1/1 | 9.100000000 | 9.100000000 to 9.100000000 | 2779187057/5658662600/154663193 |
| gamteb-strict | normal | rune:new | O2 | compile | 1/1 | 1.770000000 | 1.770000000 to 1.770000000 | - |
| gamteb-strict | normal | rune:new | O2 | correctness | 1/1 | 12.810000000 | 12.810000000 to 12.810000000 | - |
| gamteb-strict | normal | rune:new | O2 | count | 1/1 | 15.070000000 | 15.070000000 to 15.070000000 | 1729580165/5658662600/154663193 |
| gamteb-strict | normal | rune:jit | O2 | compile | 1/1 | 1.740000000 | 1.740000000 to 1.740000000 | - |
| gamteb-strict | normal | rune:jit | O2 | correctness | 1/1 | 6.000000000 | 6.000000000 to 6.000000000 | - |
| gamteb-strict | normal | rune:jit | O2 | count | 1/1 | 6.290000000 | 6.290000000 to 6.290000000 | 1729580165/5658662600/154663193 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

