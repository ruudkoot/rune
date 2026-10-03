# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| spellcheck-lazy | normal | rune | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| spellcheck-lazy | normal | rune | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| spellcheck-lazy | normal | rune | O2 | count | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | 40248813/25169312/646930 |
| spellcheck-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| spellcheck-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| spellcheck-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| spellcheck-lazy | normal | rune:opt | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 40248813/25169312/646930 |
| spellcheck-lazy | normal | rune:new | O2 | compile | 1/1 | 1.560000000 | 1.560000000 to 1.560000000 | - |
| spellcheck-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| spellcheck-lazy | normal | rune:new | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 23648414/25169312/646930 |
| spellcheck-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| spellcheck-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| spellcheck-lazy | normal | rune:jit | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 23648414/25169312/646930 |
| spellcheck-strict | normal | rune | O2 | compile | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | - |
| spellcheck-strict | normal | rune | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| spellcheck-strict | normal | rune | O2 | count | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | 34350401/10773160/247035 |
| spellcheck-strict | normal | rune:opt | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| spellcheck-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| spellcheck-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| spellcheck-strict | normal | rune:opt | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 34350401/10773160/247035 |
| spellcheck-strict | normal | rune:new | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| spellcheck-strict | normal | rune:new | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| spellcheck-strict | normal | rune:new | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 19999386/10773160/247035 |
| spellcheck-strict | normal | rune:jit | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| spellcheck-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| spellcheck-strict | normal | rune:jit | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 19999386/10773160/247035 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

