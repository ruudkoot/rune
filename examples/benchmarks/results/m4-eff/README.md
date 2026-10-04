# Pure state encodings

Recorded 2026-10-04. Andras Kovacs's seven encodings retain their original names
and distinct monadic/handler/constructor layers. These are pure library state
representations; importing them adds no compiler or runtime effect facility.

[All 196 final smoke/normal cases](correctness.tsv) pass on four Rune
engines at both optimization levels and all six managed native hosts, including 28 additional ML Kit/32-bit SML/NJ cases. Fourteen
semantic checks pass all ten configurations at both levels. Original GHC
observers agree with the selected unit/strict-counter results; the S demand
observer confirms its counter arithmetic remains unforced until explicitly read.

Smoke uses 100 increments and normal 1,000,000. Large retains the original
10,000,000 and is not universally validated on SML. S validates its unit result
while keeping the counter unforced; the other six additionally validate the
already forced final counter. S's output provides limited discrimination, so
source review and demand/sharing tests document its computation. Optimization
of unused work remains a diagnostic question.

Complete count samples and source/input/tool/configuration identities are
retained for all seven variants. Allocations and applicable instruction pairs
agree. Instrumented times are not headline timing evidence. The exact-name
filter selects S independently of CS/FS/VS and other names; substring matching
remains available. M4 remains in progress for the remaining applications.
