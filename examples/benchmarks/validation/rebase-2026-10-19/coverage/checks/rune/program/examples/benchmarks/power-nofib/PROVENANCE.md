# power-nofib provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/power/Main.hs`.

### Algorithm, history and variants

Force rational power-series identities and generating functions repeatedly.

The spectral variant uses Rational for all four lists due to rnfListOfRational
and repeats 200 times. Positive counts preserve salt=min0 p and exponent2.
Smoke5x1 bounds routine work; normal14x200 preserves original FAST, and
large26x200 preserves original NORM. Original SLOW 36 remains recorded.
Rendering/validation additionally consumes results discarded by original rnf.
The GC variant power retains integer generating functions and one printed run.

Douglas McIlroy's *Power series, power serious*, JFP 9(3), May 1999, is
identified in the original header. The individual program licence is unspecified;
this provenance gap remains explicit. Original source/builds/fixtures are retained
with SHA256 identities. Exact rational normalization follows the pinned GHC
9.4.7 base Integer Ratio operations; the library source, revision and notice are
retained separately and do not license the nofib program.

### Translation and runtime questions

Preserve finite Pz, memoized coefficient/spine demand and sharing, scalar
multiplication, the original product recurrence (including x*fs*gs), leading-zero
division, composition, reversion, differentiation, integration and square roots.
Integration emits zero before inspecting its operand, as required by the source's
differential-equation construction. Sine/cosine, geometric, Catalan and tree
series remain shared recursive knots. SML97 references implement delays; no
finite-array algebra or eager infinite-series variant replaces the algorithm.
Only operations used by the workload and finite boundary checks are ported; the
full original module remains available. Fractional operations are not applied
to the integer instantiation. Negative numerators retain GHC Show parentheses.

### Inputs, validation and references

Every requested coefficient is rendered and checked exactly. Original GHC
and read-only observers agree with all fixtures. Independent analytic identities
supply the two zero series; binomial Catalan counts supply the two combinatorial
series. Semantic checks cover finite-product length, derivative/integral values,
leading-zero division, demand before operand inspection and coefficient sharing.
Added rendering/validation work is included. Rational normalization, delay
closures, prefix retention and recursive sharing are source-derived diagnostic
hypotheses until measured. Large SML execution is not universally claimed.

[McIlroy, Power series, power serious](https://doi.org/10.1017/S0956796899003299)
motivates exact compositional streams. The concrete recurrence/forcing decisions
above come from the retained source; they are not measured performance findings.
