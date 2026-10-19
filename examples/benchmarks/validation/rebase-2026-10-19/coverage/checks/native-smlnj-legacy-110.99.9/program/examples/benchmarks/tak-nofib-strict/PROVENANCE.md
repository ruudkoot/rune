# tak-nofib-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/tak/Main.hs`.
Authorship is unknown: the source explicitly records unknown provenance (Partain, 1995-01-25).
Retain the complete upstream source, Makefile and available output fixtures.

Evaluate all three recursive Takeuchi arguments strictly.

The Haskell source can leave the third recursive argument unevaluated when the outer comparison returns another result. The lazy port memoizes each argument computation and passes the same delay cells into recursive calls, preserving demand and sharing. The strict port fully evaluates all three calls, changing work/allocation while retaining the same function value. Both variants are separately named and checked. Selected inputs fit every supported machine integer width; large preserves nofib normal parameters 35/17/8.
Smoke and normal bound work without changing the algorithm. Large is explicitly
selected from upstream parameters, and is not claimed as executed on every
engine. Process/argument plumbing is a thin SML driver; return and validate
the actual result. Calls, thunk forcing and allocation are source hypotheses
until measured. See [Partain and the nofib literature](../literature.md).

The strict recurrence is shared in `../shared/tak.sml`. Classic and nofib
drivers retain their distinct parameters and result formatting; the kernel
is identical and both upstream provenances are retained.
