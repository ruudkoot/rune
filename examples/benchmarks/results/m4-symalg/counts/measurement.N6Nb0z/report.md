# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| symalg-lazy | normal | rune | O2 | compile | 1/1 | 4.760000000 | 4.760000000 to 4.760000000 | - |
| symalg-lazy | normal | rune | O2 | correctness | 1/1 | 3.120000000 | 3.120000000 to 3.120000000 | - |
| symalg-lazy | normal | rune | O2 | count | 1/1 | 2.950000000 | 2.950000000 to 2.950000000 | 342399953/485828440/12161621 |
| symalg-lazy | normal | rune:opt | O2 | compile | 1/1 | 5.470000000 | 5.470000000 to 5.470000000 | - |
| symalg-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | - |
| symalg-lazy | normal | rune:opt | O2 | correctness | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| symalg-lazy | normal | rune:opt | O2 | count | 1/1 | 0.870000000 | 0.870000000 to 0.870000000 | 342399953/485828440/12161621 |
| symalg-lazy | normal | rune:new | O2 | compile | 1/1 | 3.970000000 | 3.970000000 to 3.970000000 | - |
| symalg-lazy | normal | rune:new | O2 | correctness | 1/1 | 1.770000000 | 1.770000000 to 1.770000000 | - |
| symalg-lazy | normal | rune:new | O2 | count | 1/1 | 2.350000000 | 2.350000000 to 2.350000000 | 192038308/485828440/12161621 |
| symalg-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.840000000 | 3.840000000 to 3.840000000 | - |
| symalg-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.730000000 | 0.730000000 to 0.730000000 | - |
| symalg-lazy | normal | rune:jit | O2 | count | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | 192038308/485828440/12161621 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

