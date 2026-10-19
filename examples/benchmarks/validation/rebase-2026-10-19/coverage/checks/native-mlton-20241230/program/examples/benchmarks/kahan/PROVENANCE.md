# kahan provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/kahan/Main.hs`. Complete original source,
Makefile and available upstream fixtures are retained with SHA256SUMS.

Algorithm: retain the 100-element sum/correction arrays, outer seeds 1..n,
xorshift steps 13/7/17, and exact (t-s)-y correction order. GHC Word is fixed
explicitly to unsigned 64 bits. The unused final RNG value is not evaluated.
History: individual authorship/licensing is unspecified by this source;
retain its comments (including the SG initials) and this notice gap.
Adaptation: STUArray Double becomes portable mutable real arrays; representation
and unboxing therefore depend on the SML compiler. Word64.toLargeInt followed
by Real.fromLargeInt preserves unsigned input conversion. The driver observes
all sums and checks correction bounds instead of merely forcing the array.
Profiles: 4/15000/150000 vectors. Large preserves upstream FAST; upstream
normal 1500000 and slow 7500000 remain recorded, not certified profiles.
Validation: independent Python unbounded-integer xorshift sums supply all 100
exact totals; an unchanged GHC kernel with a read-only sum/correction observer
agrees. Coordinate zero is exact with zero compensation at these sizes.
For other coordinates use |s-round(exact)| <= 1024*n + 4*u*abs(exact), u=2^-52.
The first term bounds conversion rounding of n unsigned 64-bit inputs; the
second covers compensated accumulation and target conversion. Corrections
must be finite and bounded by 2*u*(abs(s)+2^64). These are conservative selected
profile checks, not a proof for arbitrary inputs or a licence to reassociate
(t-s)-y. Deliberately perturbed sum/correction states must be rejected.
Performance: array updates, real representation, word operations, conversion
and GC are source-derived diagnostic hypotheses until separately measured.
Reference: Kahan, Further Remarks on Reducing Truncation Errors (1965),
https://doi.org/10.1145/363707.363723; the pinned nofib source and suite survey.

See [the literature survey](../literature.md).
