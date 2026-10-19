# FEM legacy SML/NJ results

All Rune configurations and managed MLton, SML/NJ 32-bit/development, Poly/ML
and ML Kit invocations pass the 133-assertion semantic target. Legacy 64-bit
SML/NJ 110.99.9 has 24 and 32 incorrect-result assertions in the two recorded
groups. Both groups use host-default native settings; their differences are
not attributed to Rune O0/O2.

Both legacy normal profile attempts fail exact FEM value/report/hash checks.
All other primary cases pass. Six native smoke timing diagnostics pass on
their small input; that does not establish normal-profile correctness.

Three further fresh default processes fail 25, 26 and 25 semantic assertions.
With the same source/data and a separate 64 MiB nursery configuration, all
three processes pass all 133 checks. Recorded snapshots show large numerical
differences, including forces and displacements, not a benign formatting delta.
See legacy-numeric-differences.json and raw per-process records in the archive.

The pattern is consistent with the documented
[legacy 64-bit GC-root problem](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md).
This diagnostic does not identify the application's exact failing compiler
pass or provide a new causal reduction. Kernel arithmetic, exact expected
bits, numerical-model bounds and standard runtime defaults remain unchanged.
Incorrect normal results contribute no accepted timing measurements.
