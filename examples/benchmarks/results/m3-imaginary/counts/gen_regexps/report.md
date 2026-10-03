# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gen_regexps-lazy | normal | rune | O2 | compile | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| gen_regexps-lazy | normal | rune | O2 | correctness | 1/1 | 4.930000000 | 4.930000000 to 4.930000000 | - |
| gen_regexps-lazy | normal | rune | O2 | count | 1/1 | 5.050000000 | 5.050000000 to 5.050000000 | 414862513/1432789896/44956443 |
| gen_regexps-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.380000000 | 2.380000000 to 2.380000000 | - |
| gen_regexps-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.050000000 | 1.050000000 to 1.050000000 | - |
| gen_regexps-lazy | normal | rune:opt | O2 | correctness | 1/1 | 4.110000000 | 4.110000000 to 4.110000000 | - |
| gen_regexps-lazy | normal | rune:opt | O2 | count | 1/1 | 3.790000000 | 3.790000000 to 3.790000000 | 414862513/1432789896/44956443 |
| gen_regexps-lazy | normal | rune:new | O2 | compile | 1/1 | 2.810000000 | 2.810000000 to 2.810000000 | - |
| gen_regexps-lazy | normal | rune:new | O2 | correctness | 1/1 | 7.900000000 | 7.900000000 to 7.900000000 | - |
| gen_regexps-lazy | normal | rune:new | O2 | count | 1/1 | 7.130000000 | 7.130000000 to 7.130000000 | 247345659/1432789896/44956443 |
| gen_regexps-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.880000000 | 2.880000000 to 2.880000000 | - |
| gen_regexps-lazy | normal | rune:jit | O2 | correctness | 1/1 | 4.640000000 | 4.640000000 to 4.640000000 | - |
| gen_regexps-lazy | normal | rune:jit | O2 | count | 1/1 | 5.450000000 | 5.450000000 to 5.450000000 | 247345659/1432789896/44956443 |
| gen_regexps-strict | normal | rune | O2 | compile | 1/1 | 3.110000000 | 3.110000000 to 3.110000000 | - |
| gen_regexps-strict | normal | rune | O2 | correctness | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| gen_regexps-strict | normal | rune | O2 | count | 1/1 | 1.400000000 | 1.400000000 to 1.400000000 | 93170042/236798232/5919995 |
| gen_regexps-strict | normal | rune:opt | O2 | compile | 1/1 | 3.270000000 | 3.270000000 to 3.270000000 | - |
| gen_regexps-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.960000000 | 0.960000000 to 0.960000000 | - |
| gen_regexps-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.860000000 | 0.860000000 to 0.860000000 | - |
| gen_regexps-strict | normal | rune:opt | O2 | count | 1/1 | 0.800000000 | 0.800000000 to 0.800000000 | 93170042/236798232/5919995 |
| gen_regexps-strict | normal | rune:new | O2 | compile | 1/1 | 2.870000000 | 2.870000000 to 2.870000000 | - |
| gen_regexps-strict | normal | rune:new | O2 | correctness | 1/1 | 2.160000000 | 2.160000000 to 2.160000000 | - |
| gen_regexps-strict | normal | rune:new | O2 | count | 1/1 | 1.690000000 | 1.690000000 to 1.690000000 | 53062642/236798232/5919995 |
| gen_regexps-strict | normal | rune:jit | O2 | compile | 1/1 | 3.750000000 | 3.750000000 to 3.750000000 | - |
| gen_regexps-strict | normal | rune:jit | O2 | correctness | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| gen_regexps-strict | normal | rune:jit | O2 | count | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | 53062642/236798232/5919995 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

