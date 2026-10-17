# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| para-strict | normal | rune | O2 | compile | 1/1 | 1.740000000 | 1.740000000 to 1.740000000 | - |
| para-strict | normal | rune | O2 | correctness | 1/1 | 47.800000000 | 47.800000000 to 47.800000000 | - |
| para-strict | normal | rune | O2 | count | 1/1 | 37.380000000 | 37.380000000 to 37.380000000 | 7027735784/18091422872/576451677 |
| para-strict | normal | rune:opt | O2 | compile | 1/1 | 1.780000000 | 1.780000000 to 1.780000000 | - |
| para-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| para-strict | normal | rune:opt | O2 | correctness | 1/1 | 23.360000000 | 23.360000000 to 23.360000000 | - |
| para-strict | normal | rune:opt | O2 | count | 1/1 | 21.210000000 | 21.210000000 to 21.210000000 | 7027735784/18091422872/576451677 |
| para-strict | normal | rune:new | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| para-strict | normal | rune:new | O2 | correctness | 1/1 | 40.840000000 | 40.840000000 to 40.840000000 | - |
| para-strict | normal | rune:new | O2 | count | 1/1 | 42.670000000 | 42.670000000 to 42.670000000 | 4172224503/18091422872/576451677 |
| para-strict | normal | rune:jit | O2 | compile | 1/1 | 2.050000000 | 2.050000000 to 2.050000000 | - |
| para-strict | normal | rune:jit | O2 | correctness | 1/1 | 27.680000000 | 27.680000000 to 27.680000000 | - |
| para-strict | normal | rune:jit | O2 | count | 1/1 | 25.880000000 | 25.880000000 to 25.880000000 | 4172224503/18091422872/576451677 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

