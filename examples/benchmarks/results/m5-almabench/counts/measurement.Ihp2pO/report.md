# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| almabench | normal | rune | O2 | compile | 1/1 | 2.890000000 | 2.890000000 to 2.890000000 | - |
| almabench | normal | rune | O2 | correctness | 1/1 | 45.430000000 | 45.430000000 to 45.430000000 | - |
| almabench | normal | rune | O2 | count | 1/1 | 44.930000000 | 44.930000000 to 44.930000000 | 5361368795/10160848088/235548299 |
| almabench | normal | rune:opt | O2 | compile | 1/1 | 2.540000000 | 2.540000000 to 2.540000000 | - |
| almabench | normal | rune:opt | O2 | native-compile | 1/1 | 0.770000000 | 0.770000000 to 0.770000000 | - |
| almabench | normal | rune:opt | O2 | correctness | 1/1 | 16.640000000 | 16.640000000 to 16.640000000 | - |
| almabench | normal | rune:opt | O2 | count | 1/1 | 15.460000000 | 15.460000000 to 15.460000000 | 5361368795/10160848088/235548299 |
| almabench | normal | rune:new | O2 | compile | 1/1 | 2.350000000 | 2.350000000 to 2.350000000 | - |
| almabench | normal | rune:new | O2 | correctness | 1/1 | 34.600000000 | 34.600000000 to 34.600000000 | - |
| almabench | normal | rune:new | O2 | count | 1/1 | 42.650000000 | 42.650000000 to 42.650000000 | 3496193571/10160848088/235548299 |
| almabench | normal | rune:jit | O2 | compile | 1/1 | 2.550000000 | 2.550000000 to 2.550000000 | - |
| almabench | normal | rune:jit | O2 | correctness | 1/1 | 13.730000000 | 13.730000000 to 13.730000000 | - |
| almabench | normal | rune:jit | O2 | count | 1/1 | 13.550000000 | 13.550000000 to 13.550000000 | 3496193571/10160848088/235548299 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

