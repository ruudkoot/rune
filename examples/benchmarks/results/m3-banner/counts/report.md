# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| banner-lazy | normal | rune | O2 | compile | 1/1 | 1.680000000 | 1.680000000 to 1.680000000 | - |
| banner-lazy | normal | rune | O2 | correctness | 1/1 | 58.740000000 | 58.740000000 to 58.740000000 | - |
| banner-lazy | normal | rune | O2 | count | 1/1 | 49.380000000 | 49.380000000 to 49.380000000 | 8852386811/22166398144/688701174 |
| banner-lazy | normal | rune:opt | O2 | compile | 1/1 | 2.210000000 | 2.210000000 to 2.210000000 | - |
| banner-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| banner-lazy | normal | rune:opt | O2 | correctness | 1/1 | 20.760000000 | 20.760000000 to 20.760000000 | - |
| banner-lazy | normal | rune:opt | O2 | count | 1/1 | 19.250000000 | 19.250000000 to 19.250000000 | 8852386811/22166398144/688701174 |
| banner-lazy | normal | rune:new | O2 | compile | 1/1 | 2.010000000 | 2.010000000 to 2.010000000 | - |
| banner-lazy | normal | rune:new | O2 | correctness | 1/1 | 51.700000000 | 51.700000000 to 51.700000000 | - |
| banner-lazy | normal | rune:new | O2 | count | 1/1 | 50.760000000 | 50.760000000 to 50.760000000 | 5305083533/22166398144/688701174 |
| banner-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| banner-lazy | normal | rune:jit | O2 | correctness | 1/1 | 28.630000000 | 28.630000000 to 28.630000000 | - |
| banner-lazy | normal | rune:jit | O2 | count | 1/1 | 29.330000000 | 29.330000000 to 29.330000000 | 5305083533/22166398144/688701174 |
| banner-strict | normal | rune | O2 | compile | 1/1 | 1.730000000 | 1.730000000 to 1.730000000 | - |
| banner-strict | normal | rune | O2 | correctness | 1/1 | 14.190000000 | 14.190000000 to 14.190000000 | - |
| banner-strict | normal | rune | O2 | count | 1/1 | 14.520000000 | 14.520000000 to 14.520000000 | 2962641515/4156746856/103918639 |
| banner-strict | normal | rune:opt | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| banner-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| banner-strict | normal | rune:opt | O2 | correctness | 1/1 | 6.040000000 | 6.040000000 to 6.040000000 | - |
| banner-strict | normal | rune:opt | O2 | count | 1/1 | 6.920000000 | 6.920000000 to 6.920000000 | 2962641515/4156746856/103918639 |
| banner-strict | normal | rune:new | O2 | compile | 1/1 | 1.940000000 | 1.940000000 to 1.940000000 | - |
| banner-strict | normal | rune:new | O2 | correctness | 1/1 | 12.900000000 | 12.900000000 to 12.900000000 | - |
| banner-strict | normal | rune:new | O2 | count | 1/1 | 16.280000000 | 16.280000000 to 16.280000000 | 1810849952/4156746856/103918639 |
| banner-strict | normal | rune:jit | O2 | compile | 1/1 | 2.280000000 | 2.280000000 to 2.280000000 | - |
| banner-strict | normal | rune:jit | O2 | correctness | 1/1 | 5.330000000 | 5.330000000 to 5.330000000 | - |
| banner-strict | normal | rune:jit | O2 | count | 1/1 | 5.340000000 | 5.340000000 to 5.340000000 | 1810849952/4156746856/103918639 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

