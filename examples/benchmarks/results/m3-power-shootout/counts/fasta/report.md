# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fasta | normal | rune | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| fasta | normal | rune | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| fasta | normal | rune | O2 | count | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | 50810174/107543616/2292768 |
| fasta | normal | rune:opt | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| fasta | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| fasta | normal | rune:opt | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| fasta | normal | rune:opt | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 50810174/107543616/2292768 |
| fasta | normal | rune:new | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| fasta | normal | rune:new | O2 | correctness | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| fasta | normal | rune:new | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 33089452/107543616/2292768 |
| fasta | normal | rune:jit | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| fasta | normal | rune:jit | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| fasta | normal | rune:jit | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 33089452/107543616/2292768 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

