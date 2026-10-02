# rfib provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/rfib/Main.hs`.
No author or individual licence notice is supplied by this source; retain this gap explicitly.
Retain the complete upstream source, Makefile and available output fixtures.

Evaluate the Double nfib recurrence and consume both recursive subresults.

Both recursive Double results are demanded exactly once; no sharing or unused argument changes the workload. The SML port evaluates n-1 before n-2 and preserves the two additions and floating comparisons. Integral profile arguments produce exact binary64 results at these sizes. An independent integer Fibonacci recurrence validates the complete result. A lazy variant is not added because all recursive subresults are consumed and no shared result is recomputed.
Smoke and normal bound work without changing the algorithm. Large is explicitly
selected from upstream parameters, and is not claimed as executed on every
engine. Process/argument plumbing is a thin SML driver; return and validate
the actual result. Calls, thunk forcing and allocation are source hypotheses
until measured. See [Partain and the nofib literature](../literature.md).
