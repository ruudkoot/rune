# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| symalg-strict | normal | rune | O2 | compile | 1/1 | 3.930000000 | 3.930000000 to 3.930000000 | - |
| symalg-strict | normal | rune | O2 | correctness | 1/1 | 4.780000000 | 4.780000000 to 4.780000000 | - |
| symalg-strict | normal | rune | O2 | count | 1/1 | 3.300000000 | 3.300000000 to 3.300000000 | 462088811/651348552/16345937 |
| symalg-strict | normal | rune:opt | O2 | compile | 1/1 | 3.650000000 | 3.650000000 to 3.650000000 | - |
| symalg-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| symalg-strict | normal | rune:opt | O2 | correctness | 1/1 | 1.740000000 | 1.740000000 to 1.740000000 | - |
| symalg-strict | normal | rune:opt | O2 | count | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | 462088811/651348552/16345937 |
| symalg-strict | normal | rune:new | O2 | compile | 1/1 | 4.780000000 | 4.780000000 to 4.780000000 | - |
| symalg-strict | normal | rune:new | O2 | correctness | 1/1 | 3.660000000 | 3.660000000 to 3.660000000 | - |
| symalg-strict | normal | rune:new | O2 | count | 1/1 | 2.600000000 | 2.600000000 to 2.600000000 | 259503252/651348552/16345937 |
| symalg-strict | normal | rune:jit | O2 | compile | 1/1 | 3.580000000 | 3.580000000 to 3.580000000 | - |
| symalg-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.930000000 | 2.930000000 to 2.930000000 | - |
| symalg-strict | normal | rune:jit | O2 | count | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | 259503252/651348552/16345937 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

