# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| circsim-lazy | normal | rune | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| circsim-lazy | normal | rune | O2 | correctness | 1/1 | 38.800000000 | 38.800000000 to 38.800000000 | - |
| circsim-lazy | normal | rune | O2 | count | 1/1 | 35.970000000 | 35.970000000 to 35.970000000 | 6389591596/20077281552/585417372 |
| circsim-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.890000000 | 1.890000000 to 1.890000000 | - |
| circsim-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| circsim-lazy | normal | rune:opt | O2 | correctness | 1/1 | 22.120000000 | 22.120000000 to 22.120000000 | - |
| circsim-lazy | normal | rune:opt | O2 | count | 1/1 | 21.030000000 | 21.030000000 to 21.030000000 | 6389591596/20077281552/585417372 |
| circsim-lazy | normal | rune:new | O2 | compile | 1/1 | 1.700000000 | 1.700000000 to 1.700000000 | - |
| circsim-lazy | normal | rune:new | O2 | correctness | 1/1 | 35.840000000 | 35.840000000 to 35.840000000 | - |
| circsim-lazy | normal | rune:new | O2 | count | 1/1 | 36.410000000 | 36.410000000 to 36.410000000 | 3655065955/20077281552/585417372 |
| circsim-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.550000000 | 1.550000000 to 1.550000000 | - |
| circsim-lazy | normal | rune:jit | O2 | correctness | 1/1 | 19.430000000 | 19.430000000 to 19.430000000 | - |
| circsim-lazy | normal | rune:jit | O2 | count | 1/1 | 21.180000000 | 21.180000000 to 21.180000000 | 3655065955/20077281552/585417372 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

