# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| circsim-nofib-strict | normal | rune | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| circsim-nofib-strict | normal | rune | O2 | correctness | 1/1 | 8.890000000 | 8.890000000 to 8.890000000 | - |
| circsim-nofib-strict | normal | rune | O2 | count | 1/1 | 7.010000000 | 7.010000000 to 7.010000000 | 2145733230/5250965336/99132137 |
| circsim-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| circsim-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| circsim-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 3.110000000 | 3.110000000 to 3.110000000 | - |
| circsim-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 3.330000000 | 3.330000000 to 3.330000000 | 2145733230/5250965336/99132137 |
| circsim-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | - |
| circsim-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 7.200000000 | 7.200000000 to 7.200000000 | - |
| circsim-nofib-strict | normal | rune:new | O2 | count | 1/1 | 8.580000000 | 8.580000000 to 8.580000000 | 1043756459/5250965336/99132137 |
| circsim-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 1.550000000 | 1.550000000 to 1.550000000 | - |
| circsim-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.870000000 | 2.870000000 to 2.870000000 | - |
| circsim-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 2.780000000 | 2.780000000 to 2.780000000 | 1043756459/5250965336/99132137 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

