# constraints-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/constraints/Main.hs`
and `spectral/constraints/Main.hs`. The full programs, all five solvers, 240
repetitions and FAST/NORM/SLOW sizes 6/7/8 are identical. Preserve both sources,
fixtures, Makefiles and hashes. GC-specific heap flags are reference runtime
configurations; the copies share one implementation. Andrew Tolmach and Thomas
Nordin are credited in the header, which cites WAAAPL 1999. Individual notices
are unspecified; inputs are deterministic queens CSPs generated in source.

## Algorithms and variants

Keep the CSP record (variable/value counts and relation callback), descending
assignment lists, generated search tree, label/child transformations, pruning,
leaf traversal and five methods: backtracking, backmarking, two conflict-directed
backjumping forms and forward checking. Retain cached future-domain rows,
oldest inconsistency selection, conflict sets, ordered union and nonlocal-conflict
sibling cutoff. The solvers run in their original order and each yields every
solution. The source's zero-variable backmarking result differs from the other
four methods; preserve it as an unselected edge case.

Memoized labels, children, table rows, conflict fields and conflict-list spines
represent source demand/sharing. The strict variant eagerly builds the same
finite structures through one shared functor. Assignment constructors become
integer pairs; generic list calls use portable sequence/map/filter/zip and set
helpers. Union preserves source list order and duplicate treatment. The SML
fold passes label cells so pruning can retain an unused root label without
forcing it. Representation and library-call adaptations are explicit.

## Inputs, validation and runtime questions

Smoke selects size 4 once. Normal retains FAST size 6 and all 240 original
repetitions; a bounded stack-VM -O0 preflight validates the strict normal profile
within 600 seconds/4 GiB. Large retains NORM size 7 with 240 repetitions. SLOW
size 8 is preserved in source metadata. Selected assignments, indices and count
sums fit 31 bits. The strict normal profile records a 1,200-second override after a canonical
-O0 stack run timed out at 600 seconds; memory remains 4 GiB. An earlier
bounded preflight passed at 600 seconds. Other limits retain suite defaults.

The driver consumes each complete solution vector and validates exact solution
order for every method/repetition, adding payload forcing and comparisons to the
original length-only observation. It accumulates actual solution counts per
method. GHC observers and independent permutation/diagonal checks agree on all
five full ordered solution sets for sizes 0..8, including the source's zero-case
exception. Numerical integer results are exact. Broad large SML execution is
not universally claimed.

Nine semantic checks cover five-solver agreement, source edge behavior, earliest
conflicts, strict/lazy agreement, union order, delayed pruning labels, nonlocal
backjump cutoff, cache updates and mapped-label memoization. Tree materialization,
pruning, repeated table sharing, short conflict lists and allocation/lifetimes
are source-derived hypotheses until measured. References: retained Tolmach/Nordin
implementation and WAAAPL citation, [their related 2001 publication](https://web.cecs.pdx.edu/~apt/),
Modular Lazy Search for Constraint Satisfaction Problems, and the shared nofib/GC survey.
