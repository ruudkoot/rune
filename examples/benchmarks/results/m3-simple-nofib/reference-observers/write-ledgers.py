from pathlib import Path
s=Path('examples/benchmarks');p=Path(__file__).resolve().parent
with(s/'audit.md').open('a')as f:f.write('''
## nofib SIMPLE variants and historical comparators, 2026-10-18

Four ports preserve immutable boxed arrays and both source consumers: thirteen
scalar reductions and complete array reporting, each with lazy and strict
finite-cell policies. Source step counts remain 1/20/100 at grid_max 100.
The size-ten comment is stale. Classic mutable SML implementations remain
separate. Source recursive stores, arithmetic order, Newton stopping/residual
quirks and boundary-work variable choices are retained.

The complete individual source, MAIL and C/Fortran comparators are preserved.
C explicitly credits Andy Shaw and Kofi Fynn; MAIL establishes RPaul Johnson's
Haskell/pH correspondence and Olaf Lubeck's role as Fortran supplier without
asserting sole authorship. Makefile's SRCS=Main.hs excludes both ancillary
comparators from this nofib executable. The Fortran joins source identities.
Six discovery guards bring inventory regressions to 138; all five pins replay
861 entries. No additional individual permission notice is invented.

Both initial policies agree bit for bit with complete original grid-100
states at 0/1/2/5/20/100 steps. Independent initial geometry/equation checks,
finite states, row-major scalar reductions and tolerance perturbations
supplement the original observers. Physical-model correctness is not claimed.

The catalogue contains 489 programs and 1421 profiles. M3/M4 remain in progress
and M8 remains planned. Final profile/count/acceptance outcomes are recorded
separately when their running gates finish.
''')
with(s/'literature.md').open('a')as f:f.write('''
## SIMPLE: source ancestry, functions and numeric validation

Arvind and Kattamuri Ekanadham, [Future scientific programming on parallel
machines](https://research.ibm.com/publications/future-scientific-programming-on-parallel-machines),
Journal of Parallel and Distributed Computing (1988). The IBM abstract and
metadata were reviewed; the full paper was not. Its SIMPLE excerpt and Id
Nouveau function composition provide historical context. No historical
parallelism or inlining claim is presented as a measured mechanism in Rune.

The pinned program and historical MAIL establish its own equation/edit
history, translator/correspondence roles, actual grid/step parameters and
physical-correctness caveats. Full original state and report observations
establish program agreement. Independent initial geometry, polynomial
values and scalar reductions add checks without constituting a second full
hydrodynamics solver or validation of the physical model.

Memoized immutable-array cells, recursive projections, directional sweeps,
finite strict materialization, retained old-state data, floating primitives
and full report construction/I/O remain source-based diagnostic hypotheses.
Numerical values and structure, rather than a particular host's decimal
spelling, determine correctness. Legacy SML/NJ failures remain observable
under the fixed bounds and do not contribute accepted timing samples.
''')
(s/'validation/simple-nofib-hosts.md').write_text('''# SIMPLE host and portability results

The final twenty bounded semantic groups execute all 1520 assertions:
1518 pass and two fail. Every Rune O0/O2 engine and MLton, 32-bit SML/NJ,
development SML/NJ, Poly/ML and ML Kit pass all cases. Legacy 64-bit SML/NJ
fails strict complete-state/1 in its first group and strict report-driver
in its repeated host-default group. Native O0/O2 labels use the same native
flags; they are repeated invocations, not native optimization-level evidence.

The initial tuple-selector attempt leaves 912 assertions incomplete after
six hosts reject unresolved record types; all 608 executed assertions pass.
After explicit tuple patterns, early numeric defaulting, expansive geometry
bindings and Poly/ML's unavailable optional packing module leave 760
incomplete; all 760 executed assertions pass. Source-derived numeric types
and a portable IntInf/Real.fromManExp reference decoder give full final
execution. These portability fixes change no arithmetic or expected answer.

Serial smoke timing-adapter checks reject legacy numerical preflights for
all four registered workloads. This includes the totals-only consumer,
which does not format the numerical state. MLton and Poly/ML pass their
preflights and fresh samples. Failed preflights supply no timing samples.

Separate diagnostic-only source prints the failing numerical-comparison
phase. Three default runs reject a reference comparison. Their displayed
values are not a reliable snapshot of every value in the original failing
comparison, since the logger decodes the reference again. Do not infer an
exact numeric error from those printed values alone. Three enlarged-nursery
runs hit their 1 GiB address-space limit before completing; those are
diagnostic memory failures, not evidence that a nursery setting fixes results.

The variable assertion failures are consistent with the existing
[legacy real/GC report](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md),
but no application-specific causal reduction is claimed. The canonical
sources, default runtime settings, numerical bounds and reviewed references
remain unchanged. Primary smoke/normal outcomes are recorded separately.
''')
