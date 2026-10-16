# Sequential multilayer classifier

Recorded 2026-10-16. The catalogue contains 270 programs and 804 profiles.
All 28 requested smoke/normal cases are accounted for: 27 pass, while legacy64
SML/NJ normal produces an incorrect numerical result. Every Rune engine passes
both levels and profiles; all other native hosts pass both profiles. Four normal
count samples agree across Rune engines with unchanged budgets. These counts
are separate from headline timings.

Twelve semantic/negative checks run on all ten configurations at both levels.
All pass except native32's strict decimal initialization comparison, which
fails once per level. A dyadic-reference probe confirms all 417 generated
parameters are exact; 62 decimal references are misread by one ulp. No fixture
or RNG adjustment hides this existing host defect.

Legacy64 diagnostics reproduce GC-sensitive NaNs in an untrained model. A
64-MiB nursery makes all 0/1/20-epoch checks pass; 128 KiB fails after two.
These are diagnostic settings, not suite overrides. The behavior is consistent
with the existing GC-root report; the exact faulty entry is not reduced.
The standard initial native adapter run rejects a legacy64 smoke result before
accepting any timing sample, while MLton/PolyML adapter samples validate.
The later canonical smoke result passes, demonstrating code/allocation sensitivity.
These one-sample runs are adapter diagnostics, not performance comparisons.

The port retains all 351 input rows, 34 features, labels, full Jacobian and
gradient matrices, evaluation/RNG order, SGD updates and source 1,000-epoch
large setting. All 417 initial parameters match source values on Rune/MLton.
Independent structured-derivative training validates complete 1/20-epoch
parameters and predictions; finite differences check every parameter in a tiny
network. Exact UCI data comparison, author attribution, CC BY 4.0 license,
program MIT and RNG LGPL notices are retained. Read-only data caching, fresh
model/RNG state and numerical budgets are documented.

Explicit numerical-check exceptions now receive the incorrect-result category
through the shared classifier, including the portable Fail prefix. Compiled
negative-result and runtime-exception probes validate distinct categories and
supply no timing samples. The classifier is captured in tool-source snapshots.

Coverage, all attempts, complete semantic logs, host diagnostics, source
identities and original/independent model outputs are retained. No prerequisite
compiler/runtime feature or universal large SML execution is claimed.
M5 remains in progress. See validation/multilayer-smlnj.md for interpretation.
