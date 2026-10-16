# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fasta3 | normal | rune | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| fasta3 | normal | rune | O2 | correctness | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | - |
| fasta3 | normal | rune | O2 | count | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | 91447408/50703944/1234301 |
| fasta3 | normal | rune:opt | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| fasta3 | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| fasta3 | normal | rune:opt | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| fasta3 | normal | rune:opt | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 91447408/50703944/1234301 |
| fasta3 | normal | rune:new | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| fasta3 | normal | rune:new | O2 | correctness | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| fasta3 | normal | rune:new | O2 | count | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | 70599578/50703944/1234301 |
| fasta3 | normal | rune:jit | O2 | compile | 1/1 | 1.510000000 | 1.510000000 to 1.510000000 | - |
| fasta3 | normal | rune:jit | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| fasta3 | normal | rune:jit | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 70599578/50703944/1234301 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

