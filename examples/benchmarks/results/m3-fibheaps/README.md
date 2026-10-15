# Fibonacci heaps

Recorded 2026-10-04. [All 56 final smoke/normal cases](correctness.tsv) pass
on four Rune engines at both optimization levels and all six managed native
hosts. Nine semantic checks pass all ten configurations at both levels.
Original GHC observers agree with independently generated complete histograms
for the selected 100, 30,000 and 300,000 element inputs. A separate observer
checks the two consolidation algorithms' different demand boundaries.

The [attempt ledger](correctness-attempts.tsv) retains the original-size
300,000-element strict -O0 pilot's 4 GiB memory failure and the passing memoized
pilot. Both variants use the same smaller 30,000-element normal input; large
retains the original 300,000 elements with its explicit 8 GiB limit. Large SML
execution is not universally claimed. The mutable and functional consolidations,
forest traversal orders, degree carries, tie rules and interleaved output
comparison remain distinct. The driver additionally checks ordering, complete
histograms, length and sum.

Count archives retain raw samples, source/input/tool snapshots and configuration
metadata. Allocation and applicable instruction comparisons agree across Rune
engines. Instrumented sample times are not headline timing evidence. The spectral
collection's repeated, smaller-input variant remains a separate import commitment.
M3 remains in progress.
