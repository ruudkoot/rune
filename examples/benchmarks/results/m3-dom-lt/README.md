# Dominator validation

The corrected port passes 26 of 28 primary smoke/normal cases: every Rune
O0/O2 engine and five of six managed native hosts. Native 32-bit SML/NJ fails
both profiles. All 2380 semantic assertions complete: 2220 pass and 160 fail,
all failures in the two native32 invocations. There are no unreached assertions.
Native optimization is host-default; semantic O0/O2 labels do not select distinct
native optimizer settings.

The isolated runtime Word64 zero-shift probe reproduces the existing SML/NJ
defect documented in docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md.
No arithmetic workaround is applied. The rejected native32 adapter records no
fresh timing sample. Three separate serial single fresh-process native smoke
adapter samples pass; these are diagnostics, not a comparative performance report.

Four full-normal Rune count samples pass and agree under the count conventions.
The guarded run exits zero without exceeding its resource guards. Full repository
make JOBS=4 check exits zero with 1174 profiles and all compiler/runedoc/runeopt
cross-build comparisons; its transcript is linked from validation.md.

The pinned Haskell kernel independently has a stale semidominator threshold.
Original GHC O0/O2 produces a wrong parent on a three-node counterexample.
Threshold-only repair agrees with an independent fixed-point dominator model on
86 graphs; bucket clearing alone does not. The port applies only the reviewed
threshold repair and checks every ordered parent pair on every repetition.
Its array-initialization checker and container reference observations are
separate from the uninstrumented measured instance. The historical unrepaired
variant is deferred with a correctness blocker.

Original/corrected sources, exact repair, 17 supplied graphs, additional cases,
models and raw observations retain their scope and provenance. Source fixtures
and repaired GHC FAST/NORM/SLOW checksum results agree, illustrating why the
original length-only consumer was insufficient. Full final SML large repetitions
remain unrecorded. Private pilots are development evidence; canonical source
identities and outputs identify the final registered version.
