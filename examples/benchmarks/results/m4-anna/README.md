# Anna validation and measurement-status correction, 2026-10-19

Two Anna 0.400 ports increase the catalogue to 505 programs and 1467 profiles.
M4 remains in progress pending Veritas; M8 remains open.

| Gate | Recorded outcome |
|---|---|
| Smoke and normal profiles | 45 of 56 combinations pass; all 32 Rune combinations pass across four engines and O0/O2. |
| Host exceptions | Eight smoke source-loading/compile timeouts, two normal SML/NJ32 type-inference failures, one normal lazy ML Kit compile timeout. |
| Semantics | Twelve complete groups each pass 1963 assertions. SML/NJ32 records four passes before a type-inference exception; ML Kit records a 600-second compile timeout and no assertions. |
| Normal allocation counts | All eight samples agree; both unchanged 2-GiB process-tree guards finish without intervention and retain the 8-GiB available-memory floor. |
| Final native adapter diagnostics | Four MLton/Poly/ML fresh samples pass; two legacy SML/NJ compiles exceed 30 seconds and produce no accepted timings. |
| Repository acceptance | make JOBS=4 check exits zero after 1634.7 seconds, including all 498 compiler comparisons and seven-host runedoc/runeopt agreement. |
| Measurement regressions | The existing measurement suite passes; three planted SML/NJ compile outcomes distinguish error, deadline and successful exit without an image. |

[Profile outcomes](correctness.tsv) identify every configuration and artifact.
Native hosts use host-default flags; level labels describe Rune. All defaults
remain unchanged: smoke 30 seconds/1 GiB, normal 600 seconds/4 GiB, large
3600 seconds/8 GiB. No complete large host matrix is claimed.

Normal profiles pass on Rune, MLton, legacy/development SML/NJ and Poly/ML.
ML Kit passes normal strict and times out compiling normal lazy. Smoke
SML/NJ timeouts occur while loading source, which combines compilation and
declaration work in that adapter. Keep the phase unclassified where the
raw record cannot separate it. ML Kit reports explicit compile deadlines.

## Independent original observations

The original GHC program establishes complete parsing, dependencies,
lambda lifting, inferred types, typed trees, eta abstraction, environment,
abstract-domain and full analysis results. Both portable policies match the
complete reports for all three selected inputs: 2810/28800/86941 bytes.
Their hashes agree with all 100 lines of every pinned stdout fixture.

The 11/184/601 analysis records per input agree completely in both policies.
Additional independent checks cover lattice normalization, cardinality,
domain reduction, lattice-size sequences, the random stream, shortest-path
ties, complete frontier representations and memo order. The canonical
semantic target records 23560 passing assertions and no failed assertions;
unreached assertions in two groups remain incomplete.

The original control limit and 100 repetitions are preserved. The lattice
table is read afresh each repetition. No parallel runtime is required:
Core parallel-or is an abstract truth-table value.

## Confirmed SML/NJ32 literal defect

The [existing literal-loss report](../../../../docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md)
describes the failure observed here. The actual supplied SML/NJ32 parses
0wx40000000 as zero; runtime Word64.fromString returns the correct value.
Anna uses that literal as its type-name-supply threshold. Its source program
then fails to unify list int with list int -> list int.

A separate private causal probe changes only that threshold to a runtime
read and renames the diagnostic functor. It restores the entire 837-byte
smoke type report and the Ok result. The original failed probe, private
source, exact changes, identities and successful observation are retained.
The public port keeps the valid literal. The private diagnostic is not a
runnable variant, canonical profile result or accepted timing. Other large
literal constants remain relevant; this probe establishes the type-inference
failure, not successful execution of every profile on that host.

## Source and test epochs

The first serial attempt exposed an unclosed flexible size-pair type in
fixMain. The final source annotates the sequence with its existing complete
type. Initial and final source snapshots remain separate. All canonical
profile, semantic and count gates use the closed SML97 type.

A local test initially expected cyclic EOF, passing 1962 assertions and
failing its final test. Original Parser2.hs returns one EOF token. The port
already did so. Correct the test and documentation; retain the earlier
test result and the focused corrected test. Every canonical complete
semantic group passes all 1963 assertions.

## Measurement adapter correction

The adapter previously replaced a nonzero SML/NJ compiler exit with one
when no image existed, so exit 124 appeared as a compile error. It now
preserves the actual status and only reports a missing image after a
successful compiler exit. Raw original records remain unchanged. Focused
real retries classify both 30-second deadlines correctly and accept no
timing samples. Planted tests cover actual exits 7, 124 and 0 with no image;
the last retains its actual zero and an explicit missing-image diagnostic.

The four accepted native fresh samples validate adapter execution only.
They are single-sample diagnostics, not performance comparisons or warmup
claims. SML/NJ image creation can include declaration initialization in its
compile phase; compile and execution evidence remain separate.

Final catalogue, bounded smoke and documentation checks pass after the metadata updates.
