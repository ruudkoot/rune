# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| cacheprof-nofib-strict | normal | rune | O2 | compile | 1/1 | 6.620000000 | 6.620000000 to 6.620000000 | - |
| cacheprof-nofib-strict | normal | rune | O2 | correctness | 1/1 | 16.760000000 | 16.760000000 to 16.760000000 | - |
| cacheprof-nofib-strict | normal | rune | O2 | count | 1/1 | 17.690000000 | 17.690000000 to 17.690000000 | 2255078536/4649312888/108419941 |
| cacheprof-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 4.320000000 | 4.320000000 to 4.320000000 | - |
| cacheprof-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| cacheprof-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 8.080000000 | 8.080000000 to 8.080000000 | - |
| cacheprof-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 7.180000000 | 7.180000000 to 7.180000000 | 2255078536/4649312888/108419941 |
| cacheprof-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 6.670000000 | 6.670000000 to 6.670000000 | - |
| cacheprof-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 15.550000000 | 15.550000000 to 15.550000000 | - |
| cacheprof-nofib-strict | normal | rune:new | O2 | count | 1/1 | 15.540000000 | 15.540000000 to 15.540000000 | 1285941233/4649312888/108419941 |
| cacheprof-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 4.690000000 | 4.690000000 to 4.690000000 | - |
| cacheprof-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 10.200000000 | 10.200000000 to 10.200000000 | - |
| cacheprof-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 7.440000000 | 7.440000000 to 7.440000000 | 1285941233/4649312888/108419941 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

