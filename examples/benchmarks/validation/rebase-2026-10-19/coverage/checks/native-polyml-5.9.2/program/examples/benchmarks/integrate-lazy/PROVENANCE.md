# integrate-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/integrate/Main.hs`. Complete original source,
Makefile and available upstream fixtures are retained with SHA256SUMS.

Algorithm: preserve two nested nine-point trapezoidal sums for x*y on
[0,u] x [0,2u], the analytical fourth powers, shared infinite integer inputs,
self-referential running totals, and sum of squared differences. The nine
finite samples use ordinary SML lists: every sample is demanded and used
once, in unchanged left-sum order. Laziness and sharing of the infinite
inputs and feedback totals use explicit memoized heads/spines and tied roots.
History: no individual author/licence notice is supplied; retain that gap.
Variants: strict projects the selected finite range, eagerly builds its lists
and cumulative totals, and omits infinite CAF memoization. It preserves
term/arithmetic order but changes evaluation, allocation and retained data.
Adaptation: explicit delays make call-by-need portable in SML97. Numerical
functions have explicit real types across hosts. Replace the True/False
output switch with an always-active checker, fixed range and reference path.
Profiles: 32/10000/100000 terms; large preserves original FAST. Original
normal 1000000 and slow 5000000 are retained but not selected/certified.
Validation: original GHC gives accumulated squared error exactly 0 on these
profiles, so their scalar error bound is 0. Also check both final cumulative
streams against the independent exact sum of fourth powers,
n(n+1)(2n+1)(3n^2+3n-1)/30. Their bound is 2*gamma*abs(exact), where
gamma=(n+200)*u/(1-(n+200)*u), u=2^-52; 200 covers the fixed numerical kernel
and target conversion. All states must be finite. Perturbed scalar and total
states must be rejected. This is selected-profile evidence, not an assertion
that arbitrary ranges/platforms have zero accumulated numerical error.
Performance: feedback sharing, higher-order calls, scalar representation and
retained prefixes are source hypotheses until measured. References: pinned
nofib source, its analytical bilinear integral, and the suite literature survey.

See [the literature survey](../literature.md).
