# digits-of-e2-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/digits-of-e2/Main.lhs`.
John Hughes, August 2001. Preserve complete literate source/algorithm
explanation, Makefile and upstream hash fixtures. No individual licence notice
is present; its absence remains an explicit provenance gap.

Compute e digits by lazy factorial-base carry propagation.
Keep the original finite 2*n factorial-series bound, integer-valued digits,
multiplication by ten, carry guesses and corrections. Both list spines and
head arithmetic are memoized delays: a successful carry guess emits its head
without forcing the next carry. The second digit and fractional tail retain
shared next-carry state. Exhausting the finite source is an error, not zero
padding. Count includes the initial 2 and decimal point, like source take n.
Every actual output character is consumed and compared with an independent
reviewed high-precision exp(1) fixture; output changes from a hash of Haskell
Show to a complete digit checker and repetition count. Smoke/normal use upstream
fast size 90; large upstream normal size 300. The attempted 10-character
smoke input exhausts the original Haskell finite carry bound and is rejected;
retain that original failure rather than adding zero padding. Smoke/normal/large repeats 1/100/100
computations; 100 is the original replicateM count. No strict approximation
is added: forcing an infinite continued fraction or the unreachable finite
carry tail would change termination/input semantics. Big-integer arithmetic,
sharing and demand are source hypotheses; see [nofib literature](../literature.md).
