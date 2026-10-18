# Hartel iterative-deepening search validation

Both ida-lazy and ida-strict pass all 56 primary smoke/normal cases: Rune at
O0 and O2 on stack, register, JIT and native engines, and six managed SML hosts.
The semantic target passes 108 assertions in all twenty invocations, for
2160 passing assertions with none failed or unreached. Native O0/O2 group
labels repeat host-default builds rather than select native optimization levels.

Original GHC observations cover 37 exact initial configurations and complete
ordered solution paths. An independent model agrees on all 37 ordered shuffles
and legal complete paths; breadth-first search independently establishes 33
optimal lengths. The port checks each measured result against the original
two-line output and replays every move through its final solved board.
Source seed 6, the reversed 100-element shuffle sequence, stable partitions,
cutoff behavior and tie order remain explicit. Demand tests cover shared
partitions, unused next-bound computations and solution-constructor matching.

Eight normal Rune count samples agree under the suite's instruction/allocation
comparison conventions. Both guard processes exit zero without interruption.
Six serial single fresh-process native smoke samples pass as adapter
diagnostics; they are not a ten-sample comparative timing report.

Smoke uses one width-two search, normal 600 width-three searches, and selected
large 3000 width-three searches. Repetitions remain a separate source parameter;
smoke's reduction from FAST 1500 is explicit. Per-call input/reference loading
replaces the original repeated argument access. Each repetition performs a
fresh search. Finite tile fields use memoized or strict representations while
search/control paths preserve demand. Full final SML large repetitions remain
unrecorded.

Raw canonical primary, semantic, count and native adapter records accompany
source identities and original/independent observers. Private pilots and
calibration failures are separate development evidence. Repository acceptance
is recorded separately in the suite validation ledger.

The final repository acceptance run exits zero with 1214 profiles, including
all compiler, runedoc and runeopt cross-build comparisons. The first run was
interrupted during optimization-level checks and has no final result; its log
is retained separately as development evidence. No partial run supplies this
acceptance claim.
