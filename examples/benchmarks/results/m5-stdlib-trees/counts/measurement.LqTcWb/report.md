# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| set_mem | normal | rune | O2 | compile | 1/1 | 4.740000000 | 4.740000000 to 4.740000000 | - |
| set_mem | normal | rune | O2 | correctness | 1/1 | 4.130000000 | 4.130000000 to 4.130000000 | - |
| set_mem | normal | rune | O2 | count | 1/1 | 2.280000000 | 2.280000000 to 2.280000000 | 382100958/1143216/23430 |
| set_mem | normal | rune:opt | O2 | compile | 1/1 | 4.330000000 | 4.330000000 to 4.330000000 | - |
| set_mem | normal | rune:opt | O2 | native-compile | 1/1 | 1.010000000 | 1.010000000 to 1.010000000 | - |
| set_mem | normal | rune:opt | O2 | correctness | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | - |
| set_mem | normal | rune:opt | O2 | count | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | 382100958/1143216/23430 |
| set_mem | normal | rune:new | O2 | compile | 1/1 | 4.540000000 | 4.540000000 to 4.540000000 | - |
| set_mem | normal | rune:new | O2 | correctness | 1/1 | 5.520000000 | 5.520000000 to 5.520000000 | - |
| set_mem | normal | rune:new | O2 | count | 1/1 | 2.980000000 | 2.980000000 to 2.980000000 | 227623864/1143216/23430 |
| set_mem | normal | rune:jit | O2 | compile | 1/1 | 3.330000000 | 3.330000000 to 3.330000000 | - |
| set_mem | normal | rune:jit | O2 | correctness | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | - |
| set_mem | normal | rune:jit | O2 | count | 1/1 | 0.750000000 | 0.750000000 to 0.750000000 | 227623864/1143216/23430 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

