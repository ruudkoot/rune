# bernouilli-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/bernouilli/Main.hs`. Complete original source,
Makefile and available upstream fixtures are retained with SHA256SUMS.

Algorithm: preserve the alternating power-sum formula, globally shared
infinite power rows and Pascal rows, signed powers, normalized arbitrary
precision ratios, and 64-bit nofib Show hashing. Numerators/denominators are
IntInf; ratio construction/addition follow GHC 9.4.7's reduce/gcd/cross-product
order. The spelling bernouilli is the established nofib name; Bernoulli is
the mathematical alias. No individual author/licence is supplied; the source
records a March 2003 Haskell-cafe discussion and its own GMP-performance caveat.
Variants: strict builds needed finite power/Pascal rows eagerly per repetition
and drops the global memoized cache. The recurrence and exact arithmetic are
preserved; forcing, caching, recomputation and retention differ materially.
Adaptation: memoized list heads/spines and explicitly tied roots preserve
feedback sharing; SML IntInf replaces Integer/Ratio. Haskell Show syntax,
including parentheses around negative numerators, and wrapping 64-bit hashes
are retained. SML strings materialize the shown characters; record this
representation change. Replace 500 printed hashes with checked computations
and one consumed repetition sum. Every rational and hash is validated.
Profiles: (8,1)/(60,5)/(180,500). Normal uses original FAST size; large uses
original NORM and 500 repetitions. Original SLOW size 320 remains recorded.
Validation: independent Akiyama-Tanigawa rational recurrence agrees with
unchanged GHC numerator/denominator observers at 8/60/180. The 60-index hash
also agrees with the pinned original fast fixture; other hashes use an
independent 64-bit polynomial fold over reviewed Show strings. Performance
questions about sharing, gcd, big integers and allocation remain hypotheses
until measured. References: original source/discussion note, pinned GHC Ratio
operations, nofib survey. Large SML execution is not universally claimed.

See [the literature survey](../literature.md).
