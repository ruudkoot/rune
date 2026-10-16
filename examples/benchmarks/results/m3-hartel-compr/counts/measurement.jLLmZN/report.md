# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| listcompr-strict | normal | rune | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| listcompr-strict | normal | rune | O2 | correctness | 1/1 | 4.340000000 | 4.340000000 to 4.340000000 | - |
| listcompr-strict | normal | rune | O2 | count | 1/1 | 3.970000000 | 3.970000000 to 3.970000000 | 595538582/2246828400/67147720 |
| listcompr-strict | normal | rune:opt | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| listcompr-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| listcompr-strict | normal | rune:opt | O2 | correctness | 1/1 | 2.750000000 | 2.750000000 to 2.750000000 | - |
| listcompr-strict | normal | rune:opt | O2 | count | 1/1 | 2.870000000 | 2.870000000 to 2.870000000 | 595538582/2246828400/67147720 |
| listcompr-strict | normal | rune:new | O2 | compile | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| listcompr-strict | normal | rune:new | O2 | correctness | 1/1 | 4.370000000 | 4.370000000 to 4.370000000 | - |
| listcompr-strict | normal | rune:new | O2 | count | 1/1 | 5.040000000 | 5.040000000 to 5.040000000 | 364238707/2246828400/67147720 |
| listcompr-strict | normal | rune:jit | O2 | compile | 1/1 | 3.220000000 | 3.220000000 to 3.220000000 | - |
| listcompr-strict | normal | rune:jit | O2 | correctness | 1/1 | 3.740000000 | 3.740000000 to 3.740000000 | - |
| listcompr-strict | normal | rune:jit | O2 | count | 1/1 | 3.570000000 | 3.570000000 to 3.570000000 | 364238707/2246828400/67147720 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

