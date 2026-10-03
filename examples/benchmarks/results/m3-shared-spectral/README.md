# Shared spectral sequence and relation kernels

Recorded 2026-10-03. Spectral LCSS and treejoin retain their established
names, upstream parameters and materially different datasets while sharing
the reviewed memoized/strict GC kernels. M3 remains in progress.

[All 96 primary cases](correctness.tsv) pass smoke/normal on four Rune
engines at both optimization levels and four managed native hosts. LCSS
retains 500 normal repetitions and full sequence checks; its original GHC
outputs agree with independent intersections of the selected monotone
sequences. Treejoin retains 100 normal repetitions and shuffled relation
inputs. Full five-field output agrees with GHC observers and independent
relational joins. Earlier general kernel tests cover tie selection, memoized
demand, duplicate rejection and boundary lookup. Large SML execution is
not universally claimed.

Separate count archives retain every instrumented sample, source/input/tool
snapshot and configuration identity. Allocation counts agree across all four
Rune engines; applicable instruction comparisons agree. Instrumented times
are not headline timing evidence. Compiled payloads and disposable working
directories are excluded.
