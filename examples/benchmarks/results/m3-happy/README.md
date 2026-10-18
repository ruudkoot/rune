# Happy parser-generator validation, 2026-10-18

This wave imports happy-lazy and happy-strict from the pinned nofib gc/happy
program. It preserves the selected Haskell-function backend, empty template,
complete grammar input, historical notices and separately named finite-data
policies. The suite contains 491 programs and 1425 profiles.
M3 and M4 remain in progress; M8 remains planned.

| Gate | Recorded outcome |
|---|---|
| Full profile matrix | 78 of 80 tagged runs pass: all 40 normal runs, 38 of 40 smoke runs. |
| Remaining profile attempts | Two lazy smoke ML Kit compiles have empty logs; the cause is unclassified. The same host passes both normal runs and the complete semantic target. |
| Semantics | 2514 assertions on each of 20 configuration/level groups: 50280 passes, zero failures. |
| Normal counts | Eight samples across four Rune engines and two policies; applicable comparisons agree, both resource guards exit zero without interruption. |
| Final native adapter diagnostics | All six serial fresh samples, correctness preflights and compilations pass on MLton, legacy SML/NJ and Poly/ML. |
| Repository acceptance | make JOBS=4 check exits zero, including 498 compiler comparisons and seven-host runedoc/runeopt agreement. |
| Inventory | 143 regression tests pass; all five pinned inventories still account for 861 entries. |

Requested O0/O2 levels apply to Rune. The native SML hosts repeat their
host-default compiler options; these repetitions do not establish native
optimization-level comparisons. The 80 raw rows and all failures are retained.
Single fresh samples validate adapters and are not headline performance results.
The final fresh diagnostics ran after the heavier task checks finished.

## Independent reference and source fidelity

The unchanged original GHC executable and the observer produce identical
706113-byte normal parser source, SHA-256
b70da0bb178d71e52aa624e57ae8d0955ab7f905941187c96285e0874639e793.
Complete private stage observers check lexer/token content, bootstrap and
attribute ASTs, full mangled grammars, set shapes, FIRST and LR closures,
state numbering, all lookahead stages, goto/action entries, conflicts,
complete generated source and warning bytes. All 24 complete output/warning
observations agree between original GHC and both finite-data policies.

The public semantic target includes 553 literal cases, all 542 semantic
actions from TestInput.y plus 13 synthetic actions, eleven small complete
grammars, six integer-domain boundary cases, 36 complete set fixtures,
planted output faults, ignored-argument controls, demand and sharing.
One invalid integer-reader partial-pattern case compares exception category,
not GHC-specific source-location text. The selected benchmark input stays
inside the explicit portable 31-bit integer domain.

## Host observations and resource limits

Smoke explicitly overrides the default to 120 seconds/4 GiB because the
existing correctness runner applies those limits to compilation too;
normal retains 600 seconds/4 GiB. Earlier 30-second development-host compile
timeouts and 1-GiB attempts remain preliminary evidence. An empty ML Kit log
is not proof of an out-of-memory failure.

The old literal guard exposes a reproduced SML/NJ32 dynamic subtraction
false Overflow. The independent small reproducer passes on the other five
SML hosts. Equivalent quotient/remainder limits avoid that defect; new
hex/octal boundary controls also prevent overflow from becoming a decimal
prefix. Expected results and selected algorithms are unchanged.

The native correctness runner can return from a compile failure before
recording its exit code. Its displayed exit 0 can therefore be the default
runner value. The two empty-log attempts are classified as unclassified
compile failures; no actual compiler status or cause is invented. Capturing
native compile statuses and testing their timeout classification remains an
explicit M8 follow-up. Raw records are preserved.

## Evidence layout and reproduction

correctness.tsv includes all final profile/configuration outcomes.
semantics.tsv records all assertion groups. counts/ and
fresh-adapter-diagnostics/ contain complete sample tables, reports,
configuration identities, source/input identities and readable build
metadata. Compiled executables and caches are deliberately excluded:
rebuild from the recorded source/order/options instead. The excluded
payload table covers encountered binary files; cache directories are
pruned before traversal and their contents are not inventoried individually.
A dash hash denotes an excluded compiled suffix that was not read.

reference-observers/ contains original-language probes, portable adaptation
pieces, complete expected stage observations and source epochs. The
before-nj32-guard and before-radix-overflow-fix directories contain
preliminary subjects and interrupted attempts. The first lazy count run
completed successfully before interruption; it is preliminary evidence,
not a final-source count. Reconstructed prior subjects are not claimed.
Protected ML Kit lock files and compiled cache directories are not retained.

Run make bench-check with BENCH_FILTER=happy-, BENCH_PROFILE=smoke or normal
and the desired BENCH_CONFIGS. Run sh tests/benchmarks/check-happy.sh for the
broader semantic target. Use make bench-count with the normal profile for
counts. The archived launcher scripts record exact commands and versions.
