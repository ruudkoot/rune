# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| boyer-nofib-lazy | normal | rune | O2 | compile | 1/1 | 2.830000000 | 2.830000000 to 2.830000000 | - |
| boyer-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 30.130000000 | 30.130000000 to 30.130000000 | - |
| boyer-nofib-lazy | normal | rune | O2 | count | 1/1 | 29.470000000 | 29.470000000 to 29.470000000 | 5506722585/15409930400/467913076 |
| boyer-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.910000000 | 1.910000000 to 1.910000000 | - |
| boyer-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| boyer-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 15.250000000 | 15.250000000 to 15.250000000 | - |
| boyer-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 14.760000000 | 14.760000000 to 14.760000000 | 5506722585/15409930400/467913076 |
| boyer-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| boyer-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 27.030000000 | 27.030000000 to 27.030000000 | - |
| boyer-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 26.170000000 | 26.170000000 to 26.170000000 | 2989690335/15409930400/467913076 |
| boyer-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.080000000 | 2.080000000 to 2.080000000 | - |
| boyer-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 11.460000000 | 11.460000000 to 11.460000000 | - |
| boyer-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 12.420000000 | 12.420000000 to 12.420000000 | 2989690335/15409930400/467913076 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

