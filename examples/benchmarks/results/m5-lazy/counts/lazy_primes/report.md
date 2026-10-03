# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lazy_primes | normal | rune | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| lazy_primes | normal | rune | O2 | correctness | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| lazy_primes | normal | rune | O2 | count | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | 26471199/87154024/2597577 |
| lazy_primes | normal | rune:opt | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| lazy_primes | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| lazy_primes | normal | rune:opt | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| lazy_primes | normal | rune:opt | O2 | count | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | 26471199/87154024/2597577 |
| lazy_primes | normal | rune:new | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| lazy_primes | normal | rune:new | O2 | correctness | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| lazy_primes | normal | rune:new | O2 | count | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | 17133721/87154024/2597577 |
| lazy_primes | normal | rune:jit | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| lazy_primes | normal | rune:jit | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| lazy_primes | normal | rune:jit | O2 | count | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | 17133721/87154024/2597577 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

