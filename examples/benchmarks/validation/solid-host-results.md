# Solid SML/NJ result differences

The canonical smoke/normal matrix records 50 passes and six incorrect normal
results. All Rune O0/O2 engines, MLton, Poly/ML and ML Kit pass. Each SML/NJ
normal invocation fails: five reject complete formatting and legacy 64-bit
strict rejects an exact area count first. All native smoke preflights and six
single fresh-process diagnostics pass on their shallower sweep.

A standalone formatter probe, independent of the CSG kernel, observes
Real.fmt (FIX (SOME 24)) on exactly representable binary64 values.
All three SML/NJ builds emit 0.963493347167968800000000 for
0.96349334716796875, rather than its exact 24-place decimal
0.963493347167968750000000. At depth twelve they similarly emit
0.963510453701019300000000 rather than 0.963510453701019287109375.
MLton, Poly/ML and ML Kit pass all three isolated checks. This output/library
difference is distinct from numerical computation in the CSG kernel.

The 245-assertion semantic matrix records one incorrect legacy 64-bit depth-eight
area, with every other assertion reached. Its repeated host-default invocation
passes. Native O0/O2 labels use identical native flags and are not optimization
level evidence. The variable numerical failure is consistent with the existing
[GC-root report](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md),
but no application-specific causal reduction is claimed.

The exact area references, FIX24 output contract, source operation order and
default runtime settings are unchanged. Incorrect normal runs contribute no
accepted timing samples. Formatter probes, initial diagnostic setup mistakes,
source repair counterexamples and all raw profile outcomes remain archived.
