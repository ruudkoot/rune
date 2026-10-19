# queens-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/queens/Main.hs`.
The source says it was taken from the LML distribution. Individual author
and notice are not stated in this file; `NOTICE` records that outstanding
lookup rather than assigning another collection's license. Original source,
Makefile and fast/normal/slow fixtures are retained.

Enumerate placements by levels: each prior board precedes columns 1 through
n, with the original short-circuit row/diagonal safety test. The Haskell
list comprehension is translated into memoized stream tails in
`shared/queens.sml`; pending functions are released after forcing. Exceptions
are memoized and recursive forcing is detected by `shared/lazy.sml`. The
outer count forces the complete solution stream; board suffixes remain
shared. No complete solution list is retained by the counter. Integer values
and counts fit a signed 31-bit integer for selected profiles; repetition
totals use IntInf. There are no external inputs or random choices.

Smoke counts size 4 (2); normal counts size 10 (724); large counts size 12
(14200), preserving upstream's fast input. Upstream normal/slow sizes 13/14
and their 73712/365596 fixtures remain recorded rather than being silently
replaced. The unchanged Haskell original compiled with GHC agrees on all
selected sizes. The strict variant uses the same board/safety/order logic
but eagerly constructs levels; different forcing, retention and allocation
justify separate names. Sandmark `nqueens` instead counts depth-first with
mutable sibling counters. These differences are source-based hypotheses;
no measured performance cause is claimed. See
[Partain and the nofib survey](../literature.md).
