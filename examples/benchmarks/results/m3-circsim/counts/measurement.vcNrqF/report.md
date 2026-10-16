# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| circsim-nofib-lazy | normal | rune | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| circsim-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 35.630000000 | 35.630000000 to 35.630000000 | - |
| circsim-nofib-lazy | normal | rune | O2 | count | 1/1 | 34.940000000 | 34.940000000 to 34.940000000 | 6393614970/20089116768/585769336 |
| circsim-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| circsim-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| circsim-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 18.020000000 | 18.020000000 to 18.020000000 | - |
| circsim-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 19.630000000 | 19.630000000 to 19.630000000 | 6393614970/20089116768/585769336 |
| circsim-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| circsim-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 38.440000000 | 38.440000000 to 38.440000000 | - |
| circsim-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 39.030000000 | 39.030000000 to 39.030000000 | 3657463634/20089116768/585769336 |
| circsim-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| circsim-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 20.690000000 | 20.690000000 to 20.690000000 | - |
| circsim-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 17.170000000 | 17.170000000 to 17.170000000 | 3657463634/20089116768/585769336 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

