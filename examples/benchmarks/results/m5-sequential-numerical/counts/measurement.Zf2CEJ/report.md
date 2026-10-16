# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| levinson-durbin | normal | rune | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| levinson-durbin | normal | rune | O2 | correctness | 1/1 | 0.520000000 | 0.520000000 to 0.520000000 | - |
| levinson-durbin | normal | rune | O2 | count | 1/1 | 0.560000000 | 0.560000000 to 0.560000000 | 131521420/347197824/8010642 |
| levinson-durbin | normal | rune:opt | O2 | compile | 1/1 | 1.680000000 | 1.680000000 to 1.680000000 | - |
| levinson-durbin | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| levinson-durbin | normal | rune:opt | O2 | correctness | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| levinson-durbin | normal | rune:opt | O2 | count | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | 131521420/347197824/8010642 |
| levinson-durbin | normal | rune:new | O2 | compile | 1/1 | 1.710000000 | 1.710000000 to 1.710000000 | - |
| levinson-durbin | normal | rune:new | O2 | correctness | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | - |
| levinson-durbin | normal | rune:new | O2 | count | 1/1 | 0.620000000 | 0.620000000 to 0.620000000 | 94430451/347197824/8010642 |
| levinson-durbin | normal | rune:jit | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| levinson-durbin | normal | rune:jit | O2 | correctness | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| levinson-durbin | normal | rune:jit | O2 | count | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | 94430451/347197824/8010642 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

