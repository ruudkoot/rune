# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lift-strict | normal | rune | O2 | compile | 1/1 | 2.510000000 | 2.510000000 to 2.510000000 | - |
| lift-strict | normal | rune | O2 | correctness | 1/1 | 12.150000000 | 12.150000000 to 12.150000000 | - |
| lift-strict | normal | rune | O2 | count | 1/1 | 17.300000000 | 17.300000000 to 17.300000000 | 1683526991/5354402024/128469823 |
| lift-strict | normal | rune:opt | O2 | compile | 1/1 | 3.070000000 | 3.070000000 to 3.070000000 | - |
| lift-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| lift-strict | normal | rune:opt | O2 | correctness | 1/1 | 9.190000000 | 9.190000000 to 9.190000000 | - |
| lift-strict | normal | rune:opt | O2 | count | 1/1 | 8.030000000 | 8.030000000 to 8.030000000 | 1683526991/5354402024/128469823 |
| lift-strict | normal | rune:new | O2 | compile | 1/1 | 3.150000000 | 3.150000000 to 3.150000000 | - |
| lift-strict | normal | rune:new | O2 | correctness | 1/1 | 14.300000000 | 14.300000000 to 14.300000000 | - |
| lift-strict | normal | rune:new | O2 | count | 1/1 | 11.940000000 | 11.940000000 to 11.940000000 | 1000006164/5354402024/128469823 |
| lift-strict | normal | rune:jit | O2 | compile | 1/1 | 2.750000000 | 2.750000000 to 2.750000000 | - |
| lift-strict | normal | rune:jit | O2 | correctness | 1/1 | 6.780000000 | 6.780000000 to 6.780000000 | - |
| lift-strict | normal | rune:jit | O2 | count | 1/1 | 4.940000000 | 4.940000000 to 4.940000000 | 1000006164/5354402024/128469823 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

