# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| caml_hash_tuple | normal | rune | O2 | compile | 1/1 | 2.500000000 | 2.500000000 to 2.500000000 | - |
| caml_hash_tuple | normal | rune | O2 | correctness | 1/1 | 1.890000000 | 1.890000000 to 1.890000000 | - |
| caml_hash_tuple | normal | rune | O2 | count | 1/1 | 1.860000000 | 1.860000000 to 1.860000000 | 221260895/130568/1663 |
| caml_hash_tuple | normal | rune:opt | O2 | compile | 1/1 | 3.370000000 | 3.370000000 to 3.370000000 | - |
| caml_hash_tuple | normal | rune:opt | O2 | native-compile | 1/1 | 0.680000000 | 0.680000000 to 0.680000000 | - |
| caml_hash_tuple | normal | rune:opt | O2 | correctness | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| caml_hash_tuple | normal | rune:opt | O2 | count | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | 221260895/130568/1663 |
| caml_hash_tuple | normal | rune:new | O2 | compile | 1/1 | 2.520000000 | 2.520000000 to 2.520000000 | - |
| caml_hash_tuple | normal | rune:new | O2 | correctness | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| caml_hash_tuple | normal | rune:new | O2 | count | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | 177202517/130568/1663 |
| caml_hash_tuple | normal | rune:jit | O2 | compile | 1/1 | 2.300000000 | 2.300000000 to 2.300000000 | - |
| caml_hash_tuple | normal | rune:jit | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| caml_hash_tuple | normal | rune:jit | O2 | count | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | 177202517/130568/1663 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

