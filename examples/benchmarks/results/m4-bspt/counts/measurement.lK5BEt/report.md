# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bspt-strict | normal | rune | O2 | compile | 1/1 | 2.960000000 | 2.960000000 to 2.960000000 | - |
| bspt-strict | normal | rune | O2 | correctness | 1/1 | 71.530000000 | 71.530000000 to 71.530000000 | - |
| bspt-strict | normal | rune | O2 | count | 1/1 | 88.810000000 | 88.810000000 to 88.810000000 | 15295778898/11068192648/329362665 |
| bspt-strict | normal | rune:opt | O2 | compile | 1/1 | 3.970000000 | 3.970000000 to 3.970000000 | - |
| bspt-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.850000000 | 0.850000000 to 0.850000000 | - |
| bspt-strict | normal | rune:opt | O2 | correctness | 1/1 | 33.770000000 | 33.770000000 to 33.770000000 | - |
| bspt-strict | normal | rune:opt | O2 | count | 1/1 | 35.740000000 | 35.740000000 to 35.740000000 | 15295778898/11068192648/329362665 |
| bspt-strict | normal | rune:new | O2 | compile | 1/1 | 4.410000000 | 4.410000000 to 4.410000000 | - |
| bspt-strict | normal | rune:new | O2 | correctness | 1/1 | 69.770000000 | 69.770000000 to 69.770000000 | - |
| bspt-strict | normal | rune:new | O2 | count | 1/1 | 88.330000000 | 88.330000000 to 88.330000000 | 9044114504/11068192648/329362665 |
| bspt-strict | normal | rune:jit | O2 | compile | 1/1 | 3.660000000 | 3.660000000 to 3.660000000 | - |
| bspt-strict | normal | rune:jit | O2 | correctness | 1/1 | 26.850000000 | 26.850000000 to 26.850000000 | - |
| bspt-strict | normal | rune:jit | O2 | count | 1/1 | 24.920000000 | 24.920000000 to 24.920000000 | 9044114504/11068192648/329362665 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

