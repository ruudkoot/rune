# queens-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/queens/Main.hs`.
The source attributes its origin to the LML distribution; individual author
and license are unstated. Original source/build parameters/fixtures and the
unresolved individual-notice lookup are retained in this directory.

Preserve the board-first list-comprehension order, columns 1 through n,
short-circuit safety test and shared board suffixes. Evaluate the generated
levels eagerly using map, mapPartial and concatenation before taking length.
This deliberately changes Haskell's demand and allocation behavior; the
faithful memoized `queens-lazy` variant remains separately available.
No mutation, randomness, numeric-width substitution or external data is
introduced. Selected counts fit signed 31-bit integers; the outer repetition
total uses IntInf. Newly written SML97 translation lives in
`shared/queens.sml`; the thin named driver consumes its count.

Profiles select sizes 4/10/12 once, yielding 2/724/14200. Size 12 is the
original fast input; upstream's normal 13 (73712) and slow 14 (365596)
are preserved in the retained Makefile/fixtures. GHC's unchanged Haskell
program agrees for selected sizes; semantic tests independently check
both SML variants for every size 1 through 10. Sandmark `nqueens` uses a
different depth-first mutable counter and stays separate. Level retention,
intermediate lists and allocation are hypotheses from source inspection,
not measured causal findings. See [the nofib literature](../literature.md).
