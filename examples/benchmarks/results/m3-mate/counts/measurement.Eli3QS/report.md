# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mate-lazy | normal | rune | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| mate-lazy | normal | rune | O2 | correctness | 1/1 | 22.780000000 | 22.780000000 to 22.780000000 | - |
| mate-lazy | normal | rune | O2 | count | 1/1 | 25.750000000 | 25.750000000 to 25.750000000 | 5087949094/8102989832/225385761 |
| mate-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.900000000 | 1.900000000 to 1.900000000 | - |
| mate-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.550000000 | 0.550000000 to 0.550000000 | - |
| mate-lazy | normal | rune:opt | O2 | correctness | 1/1 | 13.720000000 | 13.720000000 to 13.720000000 | - |
| mate-lazy | normal | rune:opt | O2 | count | 1/1 | 11.120000000 | 11.120000000 to 11.120000000 | 5087949094/8102989832/225385761 |
| mate-lazy | normal | rune:new | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| mate-lazy | normal | rune:new | O2 | correctness | 1/1 | 26.030000000 | 26.030000000 to 26.030000000 | - |
| mate-lazy | normal | rune:new | O2 | count | 1/1 | 24.730000000 | 24.730000000 to 24.730000000 | 2887239977/8102989832/225385761 |
| mate-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.730000000 | 1.730000000 to 1.730000000 | - |
| mate-lazy | normal | rune:jit | O2 | correctness | 1/1 | 9.330000000 | 9.330000000 to 9.330000000 | - |
| mate-lazy | normal | rune:jit | O2 | count | 1/1 | 9.270000000 | 9.270000000 to 9.270000000 | 2887239977/8102989832/225385761 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

