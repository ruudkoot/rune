# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| nucleic2-shared-lazy | normal | rune | O2 | compile | 1/1 | 15.010000000 | 15.010000000 to 15.010000000 | - |
| nucleic2-shared-lazy | normal | rune | O2 | correctness | 1/1 | 91.060000000 | 91.060000000 to 91.060000000 | - |
| nucleic2-shared-lazy | normal | rune | O2 | count | 1/1 | 107.050000000 | 107.050000000 to 107.050000000 | 12475301545/13048167536/327459800 |
| nucleic2-shared-lazy | normal | rune:opt | O2 | compile | 1/1 | 16.500000000 | 16.500000000 to 16.500000000 | - |
| nucleic2-shared-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 6.540000000 | 6.540000000 to 6.540000000 | - |
| nucleic2-shared-lazy | normal | rune:opt | O2 | correctness | 1/1 | 67.080000000 | 67.080000000 to 67.080000000 | - |
| nucleic2-shared-lazy | normal | rune:opt | O2 | count | 1/1 | 58.970000000 | 58.970000000 to 58.970000000 | 12475301545/13048167536/327459800 |
| nucleic2-shared-lazy | normal | rune:new | O2 | compile | 1/1 | 10.010000000 | 10.010000000 to 10.010000000 | - |
| nucleic2-shared-lazy | normal | rune:new | O2 | correctness | 1/1 | 122.930000000 | 122.930000000 to 122.930000000 | - |
| nucleic2-shared-lazy | normal | rune:new | O2 | count | 1/1 | 104.010000000 | 104.010000000 to 104.010000000 | 7763394111/13048167536/327459800 |
| nucleic2-shared-lazy | normal | rune:jit | O2 | compile | 1/1 | 9.470000000 | 9.470000000 to 9.470000000 | - |
| nucleic2-shared-lazy | normal | rune:jit | O2 | correctness | 1/1 | 51.550000000 | 51.550000000 to 51.550000000 | - |
| nucleic2-shared-lazy | normal | rune:jit | O2 | count | 1/1 | 56.080000000 | 56.080000000 to 56.080000000 | 7763394111/13048167536/327459800 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

