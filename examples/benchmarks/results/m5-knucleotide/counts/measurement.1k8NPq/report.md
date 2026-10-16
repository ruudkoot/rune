# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| knucleotide | normal | rune | O2 | compile | 1/1 | 1.650000000 | 1.650000000 to 1.650000000 | - |
| knucleotide | normal | rune | O2 | correctness | 1/1 | 8.430000000 | 8.430000000 to 8.430000000 | - |
| knucleotide | normal | rune | O2 | count | 1/1 | 8.110000000 | 8.110000000 to 8.110000000 | 1706714870/3072129112/68953237 |
| knucleotide | normal | rune:opt | O2 | compile | 1/1 | 2.400000000 | 2.400000000 to 2.400000000 | - |
| knucleotide | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| knucleotide | normal | rune:opt | O2 | correctness | 1/1 | 4.410000000 | 4.410000000 to 4.410000000 | - |
| knucleotide | normal | rune:opt | O2 | count | 1/1 | 4.470000000 | 4.470000000 to 4.470000000 | 1706714870/3072129112/68953237 |
| knucleotide | normal | rune:new | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| knucleotide | normal | rune:new | O2 | correctness | 1/1 | 8.320000000 | 8.320000000 to 8.320000000 | - |
| knucleotide | normal | rune:new | O2 | count | 1/1 | 8.230000000 | 8.230000000 to 8.230000000 | 1163477316/3072129112/68953237 |
| knucleotide | normal | rune:jit | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| knucleotide | normal | rune:jit | O2 | correctness | 1/1 | 5.210000000 | 5.210000000 to 5.210000000 | - |
| knucleotide | normal | rune:jit | O2 | count | 1/1 | 3.850000000 | 3.850000000 to 3.850000000 | 1163477316/3072129112/68953237 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

