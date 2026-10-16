# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| knucleotide3-32 | normal | rune | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| knucleotide3-32 | normal | rune | O2 | correctness | 1/1 | 3.740000000 | 3.740000000 to 3.740000000 | - |
| knucleotide3-32 | normal | rune | O2 | count | 1/1 | 3.290000000 | 3.290000000 to 3.290000000 | 628794356/766588368/19264176 |
| knucleotide3-32 | normal | rune:opt | O2 | compile | 1/1 | 1.550000000 | 1.550000000 to 1.550000000 | - |
| knucleotide3-32 | normal | rune:opt | O2 | native-compile | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| knucleotide3-32 | normal | rune:opt | O2 | correctness | 1/1 | 1.660000000 | 1.660000000 to 1.660000000 | - |
| knucleotide3-32 | normal | rune:opt | O2 | count | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | 628794356/766588368/19264176 |
| knucleotide3-32 | normal | rune:new | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| knucleotide3-32 | normal | rune:new | O2 | correctness | 1/1 | 5.140000000 | 5.140000000 to 5.140000000 | - |
| knucleotide3-32 | normal | rune:new | O2 | count | 1/1 | 3.200000000 | 3.200000000 to 3.200000000 | 425377020/766588368/19264176 |
| knucleotide3-32 | normal | rune:jit | O2 | compile | 1/1 | 1.690000000 | 1.690000000 to 1.690000000 | - |
| knucleotide3-32 | normal | rune:jit | O2 | correctness | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| knucleotide3-32 | normal | rune:jit | O2 | count | 1/1 | 1.680000000 | 1.680000000 to 1.680000000 | 425377020/766588368/19264176 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

