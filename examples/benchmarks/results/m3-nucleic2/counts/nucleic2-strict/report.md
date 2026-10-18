# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| nucleic2-strict | normal | rune | O2 | compile | 1/1 | 8.130000000 | 8.130000000 to 8.130000000 | - |
| nucleic2-strict | normal | rune | O2 | correctness | 1/1 | 78.000000000 | 78.000000000 to 78.000000000 | - |
| nucleic2-strict | normal | rune | O2 | count | 1/1 | 86.570000000 | 86.570000000 to 86.570000000 | 11009502409/859129632/12597358 |
| nucleic2-strict | normal | rune:opt | O2 | compile | 1/1 | 7.940000000 | 7.940000000 to 7.940000000 | - |
| nucleic2-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.810000000 | 1.810000000 to 1.810000000 | - |
| nucleic2-strict | normal | rune:opt | O2 | correctness | 1/1 | 36.130000000 | 36.130000000 to 36.130000000 | - |
| nucleic2-strict | normal | rune:opt | O2 | count | 1/1 | 37.680000000 | 37.680000000 to 37.680000000 | 11009502409/859129632/12597358 |
| nucleic2-strict | normal | rune:new | O2 | compile | 1/1 | 8.380000000 | 8.380000000 to 8.380000000 | - |
| nucleic2-strict | normal | rune:new | O2 | correctness | 1/1 | 76.600000000 | 76.600000000 to 76.600000000 | - |
| nucleic2-strict | normal | rune:new | O2 | count | 1/1 | 74.580000000 | 74.580000000 to 74.580000000 | 6860665760/859129632/12597358 |
| nucleic2-strict | normal | rune:jit | O2 | compile | 1/1 | 7.350000000 | 7.350000000 to 7.350000000 | - |
| nucleic2-strict | normal | rune:jit | O2 | correctness | 1/1 | 40.660000000 | 40.660000000 to 40.660000000 | - |
| nucleic2-strict | normal | rune:jit | O2 | count | 1/1 | 41.980000000 | 41.980000000 to 41.980000000 | 6860665760/859129632/12597358 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

