# digits-of-e1-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/digits-of-e1/Main.lhs`.
Dale Thurston, August 2001. Preserve complete literate source/algorithm
explanation, Makefile and upstream hash fixtures. No individual licence notice
is present; its absence remains an explicit provenance gap.

Compute e digits by lazy continued-fraction linear transformations.
Keep the infinite e continued fraction [2,1,2,1,1,4,1,1,6,...], the
source pole/interval guards and exact IntInf.div floor arithmetic. The quotient
is calculated only after the pole guard permits it, preserving short-circuit
demand. Memoize continued-fraction tails and transformation tails; the global
continued fraction remains shared across repetitions as the Haskell CAF.
Count includes the initial 2 but no decimal point.
Every actual output character is consumed and compared with an independent
reviewed high-precision exp(1) fixture; output changes from a hash of Haskell
Show to a complete digit checker and repetition count. Normal uses upstream
fast size; large upstream normal size. Smoke/normal/large repeats 1/100/100
computations; 100 is the original replicateM count. No strict approximation
is added: forcing an infinite continued fraction or the unreachable finite
carry tail would change termination/input semantics. Big-integer arithmetic,
sharing and demand are source hypotheses; see [nofib literature](../literature.md).
