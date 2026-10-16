# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| knucleotide3-64 | normal | rune | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| knucleotide3-64 | normal | rune | O2 | correctness | 1/1 | 3.100000000 | 3.100000000 to 3.100000000 | - |
| knucleotide3-64 | normal | rune | O2 | count | 1/1 | 3.430000000 | 3.430000000 to 3.430000000 | 633211813/762580400/19263970 |
| knucleotide3-64 | normal | rune:opt | O2 | compile | 1/1 | 1.740000000 | 1.740000000 to 1.740000000 | - |
| knucleotide3-64 | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| knucleotide3-64 | normal | rune:opt | O2 | correctness | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| knucleotide3-64 | normal | rune:opt | O2 | count | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | 633211813/762580400/19263970 |
| knucleotide3-64 | normal | rune:new | O2 | compile | 1/1 | 1.710000000 | 1.710000000 to 1.710000000 | - |
| knucleotide3-64 | normal | rune:new | O2 | correctness | 1/1 | 6.200000000 | 6.200000000 to 6.200000000 | - |
| knucleotide3-64 | normal | rune:new | O2 | count | 1/1 | 3.080000000 | 3.080000000 to 3.080000000 | 427446414/762580400/19263970 |
| knucleotide3-64 | normal | rune:jit | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| knucleotide3-64 | normal | rune:jit | O2 | correctness | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| knucleotide3-64 | normal | rune:jit | O2 | count | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | 427446414/762580400/19263970 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

