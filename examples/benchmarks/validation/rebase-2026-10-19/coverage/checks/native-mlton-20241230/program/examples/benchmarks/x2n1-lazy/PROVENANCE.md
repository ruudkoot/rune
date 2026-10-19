# x2n1-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/x2n1/Main.hs`. Complete original source,
Makefile and available upstream fixtures are retained with SHA256SUMS.

Algorithm: for n=1..range evaluate mkPolar 1 (2*pi/n)^n, then left-sum.
Complex components are strict, as in Data.Complex; list heads/spines are
memoized and consumed incrementally. The common helper preserves multiplication
and exponentiation order from GHC 9.4.7 base-4.17.2.0, including the f/g positive
power loop. Retain those library sources and their BSD licence.
History: Lennart Augustsson, December 1992; the source preserves his letter
to Will Partain explaining the benchmark's complex-number motivation.
Variants: strict computes the same values/order into an eager finite list
before summation. This changes evaluation and retention, so names remain
separate; both share one arithmetic kernel. No GC/compiler causal claim is made.
Adaptation: rectangular pairs replace strict Complex Double, explicit memoized
nodes replace lazy lists, and the driver observes both real and imaginary
components rather than only rounding the final real component.
Profiles: 64/10000/1000000 roots; large preserves upstream FAST, while original
normal 8000000 and slow 30000000 remain recorded but unexecuted.
Validation: each term is finite and within 16*u*n of (1,0); each final component
is within 32*u*range^2 of (range,0), u=2^-52. The final rounded real count must
also equal range. These conservative budgets cover input/trigonometric and
repeated multiplication/addition rounding on the selected positive ranges;
negative tests reject perturbations and nonfinite values. Original GHC output
agrees on all selected profiles. Reference: Augustsson's original letter,
GHC base sources and the nofib survey; unboxing, calls and retention are
source-derived hypotheses until measured.

See [the literature survey](../literature.md).
