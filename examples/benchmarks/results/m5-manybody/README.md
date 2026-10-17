# Sequential random many-body simulation

All 28 canonical smoke/normal cases pass on Rune's four engines at O0/O2 and six
native hosts at their defaults. All 49 auxiliary assertions pass in twenty
invocations (980 assertions). Four normal count samples agree under
execution-model rules, including allocation across every Rune engine. Existing
budgets remain unchanged. Three serial single fresh-process native smoke samples
validate adapters separately from headline comparisons and instrumentation.

Original OCaml 4.14.1 runs match their reference-only full-state observers in all
nine selected cases, including source-default 500-step/1024-body large input.
Only energy formatting changes to 17 significant digits; it rounds back to the
unmodified nine-fractional-digit stdout. Every final field is exported. A separate
Python generator/ordered-pair/energy model agrees exactly on all checked initial,
small, smoke and normal numbers, including 1024-body initialization. It reuses
reviewed seed words, not the SML update implementation.

The port preserves right-to-left record initialization draws, the default random
state, ordered i,j velocity updates, separate position updates and the source
solar-mass momentum denominator despite the random first mass. The existing
five-body helper supplies its identical energy/momentum loops and body type;
the ordered-pair kernel remains distinct. Inputs and references are deterministic.

Both energies and every position, velocity and mass use absolute bound 1e-9 plus
relative bound 1e-11. Tests reject a perturbation in each four-body component,
short/extra/nonfinite references, and accept an interior perturbation. They
check fresh RNG/body fields, source offset behavior and an analytic two-body
step. These are binary64 result bounds, not conservation/physical accuracy claims.

Smoke=1/16, normal=20/256 and large=500/1024 preserve the two meaningful source
parameters; large retains source defaults. Published 512/2048 and 128/8192 cases
are documented but unselected. Whole large SML integration is unrecorded.
All notices, source/library pins, dataset origins and translation decisions are
retained. Compiled artifacts are excluded.

Full make check exits 0 with 970 catalogue profiles; validation.md links the
complete transcript.
M5 remains in progress.
