# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fasta6 | normal | rune | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| fasta6 | normal | rune | O2 | correctness | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | - |
| fasta6 | normal | rune | O2 | count | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | 94220308/60961008/1327972 |
| fasta6 | normal | rune:opt | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| fasta6 | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| fasta6 | normal | rune:opt | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| fasta6 | normal | rune:opt | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 94220308/60961008/1327972 |
| fasta6 | normal | rune:new | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| fasta6 | normal | rune:new | O2 | correctness | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| fasta6 | normal | rune:new | O2 | count | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | 70636567/60961008/1327972 |
| fasta6 | normal | rune:jit | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| fasta6 | normal | rune:jit | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| fasta6 | normal | rune:jit | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 70636567/60961008/1327972 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

