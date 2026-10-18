# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| caml_hash_int | normal | rune | O2 | compile | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | - |
| caml_hash_int | normal | rune | O2 | correctness | 1/1 | 0.970000000 | 0.970000000 to 0.970000000 | - |
| caml_hash_int | normal | rune | O2 | count | 1/1 | 0.890000000 | 0.890000000 to 0.890000000 | 118157859/130568/1663 |
| caml_hash_int | normal | rune:opt | O2 | compile | 1/1 | 2.350000000 | 2.350000000 to 2.350000000 | - |
| caml_hash_int | normal | rune:opt | O2 | native-compile | 1/1 | 0.680000000 | 0.680000000 to 0.680000000 | - |
| caml_hash_int | normal | rune:opt | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| caml_hash_int | normal | rune:opt | O2 | count | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | 118157859/130568/1663 |
| caml_hash_int | normal | rune:new | O2 | compile | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| caml_hash_int | normal | rune:new | O2 | correctness | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | - |
| caml_hash_int | normal | rune:new | O2 | count | 1/1 | 0.730000000 | 0.730000000 to 0.730000000 | 91116491/130568/1663 |
| caml_hash_int | normal | rune:jit | O2 | compile | 1/1 | 2.770000000 | 2.770000000 to 2.770000000 | - |
| caml_hash_int | normal | rune:jit | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| caml_hash_int | normal | rune:jit | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 91116491/130568/1663 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

