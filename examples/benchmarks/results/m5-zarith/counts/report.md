# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| zarith_fact | normal | rune | O2 | compile | 1/1 | 1.400000000 | 1.400000000 to 1.400000000 | - |
| zarith_fact | normal | rune | O2 | correctness | 1/1 | 0.960000000 | 0.960000000 to 0.960000000 | - |
| zarith_fact | normal | rune | O2 | count | 1/1 | 0.940000000 | 0.940000000 to 0.940000000 | 234131511/291271392/7281836 |
| zarith_fact | normal | rune:opt | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| zarith_fact | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| zarith_fact | normal | rune:opt | O2 | correctness | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | - |
| zarith_fact | normal | rune:opt | O2 | count | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | 234131511/291271392/7281836 |
| zarith_fact | normal | rune:new | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| zarith_fact | normal | rune:new | O2 | correctness | 1/1 | 0.910000000 | 0.910000000 to 0.910000000 | - |
| zarith_fact | normal | rune:new | O2 | count | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | 133519837/291271392/7281836 |
| zarith_fact | normal | rune:jit | O2 | compile | 1/1 | 2.270000000 | 2.270000000 to 2.270000000 | - |
| zarith_fact | normal | rune:jit | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| zarith_fact | normal | rune:jit | O2 | count | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | 133519837/291271392/7281836 |
| zarith_fib | normal | rune | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| zarith_fib | normal | rune | O2 | correctness | 1/1 | 0.470000000 | 0.470000000 to 0.470000000 | - |
| zarith_fib | normal | rune | O2 | count | 1/1 | 0.590000000 | 0.590000000 to 0.590000000 | 122521095/107720728/2693041 |
| zarith_fib | normal | rune:opt | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| zarith_fib | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| zarith_fib | normal | rune:opt | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| zarith_fib | normal | rune:opt | O2 | count | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | 122521095/107720728/2693041 |
| zarith_fib | normal | rune:new | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| zarith_fib | normal | rune:new | O2 | correctness | 1/1 | 0.470000000 | 0.470000000 to 0.470000000 | - |
| zarith_fib | normal | rune:new | O2 | count | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | 64627370/107720728/2693041 |
| zarith_fib | normal | rune:jit | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| zarith_fib | normal | rune:jit | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| zarith_fib | normal | rune:jit | O2 | count | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | 64627370/107720728/2693041 |
| zarith_fib-int | normal | rune | O2 | compile | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| zarith_fib-int | normal | rune | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| zarith_fib-int | normal | rune | O2 | count | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | 32320875/18688/486 |
| zarith_fib-int | normal | rune:opt | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| zarith_fib-int | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| zarith_fib-int | normal | rune:opt | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| zarith_fib-int | normal | rune:opt | O2 | count | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | 32320875/18688/486 |
| zarith_fib-int | normal | rune:new | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| zarith_fib-int | normal | rune:new | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| zarith_fib-int | normal | rune:new | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 21546656/18688/486 |
| zarith_fib-int | normal | rune:jit | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| zarith_fib-int | normal | rune:jit | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| zarith_fib-int | normal | rune:jit | O2 | count | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | 21546656/18688/486 |
| zarith_fib-natint | normal | rune | O2 | compile | 1/1 | 1.190000000 | 1.190000000 to 1.190000000 | - |
| zarith_fib-natint | normal | rune | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| zarith_fib-natint | normal | rune | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 32321327/19608/509 |
| zarith_fib-natint | normal | rune:opt | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| zarith_fib-natint | normal | rune:opt | O2 | native-compile | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| zarith_fib-natint | normal | rune:opt | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| zarith_fib-natint | normal | rune:opt | O2 | count | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | 32321327/19608/509 |
| zarith_fib-natint | normal | rune:new | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| zarith_fib-natint | normal | rune:new | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| zarith_fib-natint | normal | rune:new | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 21546929/19608/509 |
| zarith_fib-natint | normal | rune:jit | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| zarith_fib-natint | normal | rune:jit | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| zarith_fib-natint | normal | rune:jit | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 21546929/19608/509 |
| zarith_fib-num | normal | rune | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| zarith_fib-num | normal | rune | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| zarith_fib-num | normal | rune | O2 | count | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | 52514912/32329288/1346761 |
| zarith_fib-num | normal | rune:opt | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| zarith_fib-num | normal | rune:opt | O2 | native-compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| zarith_fib-num | normal | rune:opt | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| zarith_fib-num | normal | rune:opt | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 52514912/32329288/1346761 |
| zarith_fib-num | normal | rune:new | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| zarith_fib-num | normal | rune:new | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| zarith_fib-num | normal | rune:new | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 30970547/32329288/1346761 |
| zarith_fib-num | normal | rune:jit | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| zarith_fib-num | normal | rune:jit | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| zarith_fib-num | normal | rune:jit | O2 | count | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | 30970547/32329288/1346761 |
| zarith_tak | normal | rune | O2 | compile | 1/1 | 2.410000000 | 2.410000000 to 2.410000000 | - |
| zarith_tak | normal | rune | O2 | correctness | 1/1 | 7.080000000 | 7.080000000 to 7.080000000 | - |
| zarith_tak | normal | rune | O2 | count | 1/1 | 6.470000000 | 6.470000000 to 6.470000000 | 2161682966/1863135160/46578483 |
| zarith_tak | normal | rune:opt | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| zarith_tak | normal | rune:opt | O2 | native-compile | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| zarith_tak | normal | rune:opt | O2 | correctness | 1/1 | 2.250000000 | 2.250000000 to 2.250000000 | - |
| zarith_tak | normal | rune:opt | O2 | count | 1/1 | 2.220000000 | 2.220000000 to 2.220000000 | 2161682966/1863135160/46578483 |
| zarith_tak | normal | rune:new | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| zarith_tak | normal | rune:new | O2 | correctness | 1/1 | 5.250000000 | 5.250000000 to 5.250000000 | - |
| zarith_tak | normal | rune:new | O2 | count | 1/1 | 5.070000000 | 5.070000000 to 5.070000000 | 1145754071/1863135160/46578483 |
| zarith_tak | normal | rune:jit | O2 | compile | 1/1 | 2.090000000 | 2.090000000 to 2.090000000 | - |
| zarith_tak | normal | rune:jit | O2 | correctness | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| zarith_tak | normal | rune:jit | O2 | count | 1/1 | 1.730000000 | 1.730000000 to 1.730000000 | 1145754071/1863135160/46578483 |
| zarith_tak-int | normal | rune | O2 | compile | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| zarith_tak-int | normal | rune | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| zarith_tak-int | normal | rune | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 77106264/21224/591 |
| zarith_tak-int | normal | rune:opt | O2 | compile | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| zarith_tak-int | normal | rune:opt | O2 | native-compile | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| zarith_tak-int | normal | rune:opt | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| zarith_tak-int | normal | rune:opt | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 77106264/21224/591 |
| zarith_tak-int | normal | rune:new | O2 | compile | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| zarith_tak-int | normal | rune:new | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| zarith_tak-int | normal | rune:new | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 36948607/21224/591 |
| zarith_tak-int | normal | rune:jit | O2 | compile | 1/1 | 1.040000000 | 1.040000000 to 1.040000000 | - |
| zarith_tak-int | normal | rune:jit | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| zarith_tak-int | normal | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 36948607/21224/591 |
| zarith_tak-natint | normal | rune | O2 | compile | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| zarith_tak-natint | normal | rune | O2 | correctness | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| zarith_tak-natint | normal | rune | O2 | count | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | 102824863/56888/1523 |
| zarith_tak-natint | normal | rune:opt | O2 | compile | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| zarith_tak-natint | normal | rune:opt | O2 | native-compile | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| zarith_tak-natint | normal | rune:opt | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| zarith_tak-natint | normal | rune:opt | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 102824863/56888/1523 |
| zarith_tak-natint | normal | rune:new | O2 | compile | 1/1 | 1.190000000 | 1.190000000 to 1.190000000 | - |
| zarith_tak-natint | normal | rune:new | O2 | correctness | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| zarith_tak-natint | normal | rune:new | O2 | count | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | 62658744/56888/1523 |
| zarith_tak-natint | normal | rune:jit | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| zarith_tak-natint | normal | rune:jit | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| zarith_tak-natint | normal | rune:jit | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 62658744/56888/1523 |
| zarith_tak-num | normal | rune | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| zarith_tak-num | normal | rune | O2 | correctness | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | - |
| zarith_tak-num | normal | rune | O2 | count | 1/1 | 0.630000000 | 0.630000000 to 0.630000000 | 210414473/115660808/4818907 |
| zarith_tak-num | normal | rune:opt | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| zarith_tak-num | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| zarith_tak-num | normal | rune:opt | O2 | correctness | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| zarith_tak-num | normal | rune:opt | O2 | count | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | 210414473/115660808/4818907 |
| zarith_tak-num | normal | rune:new | O2 | compile | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| zarith_tak-num | normal | rune:new | O2 | correctness | 1/1 | 0.620000000 | 0.620000000 to 0.620000000 | - |
| zarith_tak-num | normal | rune:new | O2 | count | 1/1 | 0.700000000 | 0.700000000 to 0.700000000 | 109224230/115660808/4818907 |
| zarith_tak-num | normal | rune:jit | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| zarith_tak-num | normal | rune:jit | O2 | correctness | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | - |
| zarith_tak-num | normal | rune:jit | O2 | count | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | 109224230/115660808/4818907 |
| zarith_pi | normal | rune | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| zarith_pi | normal | rune | O2 | correctness | 1/1 | 24.510000000 | 24.510000000 to 24.510000000 | - |
| zarith_pi | normal | rune | O2 | count | 1/1 | 23.810000000 | 23.810000000 to 23.810000000 | 5386855822/5661520376/141537291 |
| zarith_pi | normal | rune:opt | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| zarith_pi | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| zarith_pi | normal | rune:opt | O2 | correctness | 1/1 | 10.050000000 | 10.050000000 to 10.050000000 | - |
| zarith_pi | normal | rune:opt | O2 | count | 1/1 | 9.610000000 | 9.610000000 to 9.610000000 | 5386855822/5661520376/141537291 |
| zarith_pi | normal | rune:new | O2 | compile | 1/1 | 2.190000000 | 2.190000000 to 2.190000000 | - |
| zarith_pi | normal | rune:new | O2 | correctness | 1/1 | 16.950000000 | 16.950000000 to 16.950000000 | - |
| zarith_pi | normal | rune:new | O2 | count | 1/1 | 18.910000000 | 18.910000000 to 18.910000000 | 3028358806/5661520376/141537291 |
| zarith_pi | normal | rune:jit | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| zarith_pi | normal | rune:jit | O2 | correctness | 1/1 | 7.970000000 | 7.970000000 to 7.970000000 | - |
| zarith_pi | normal | rune:jit | O2 | count | 1/1 | 7.840000000 | 7.840000000 to 7.840000000 | 3028358806/5661520376/141537291 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

