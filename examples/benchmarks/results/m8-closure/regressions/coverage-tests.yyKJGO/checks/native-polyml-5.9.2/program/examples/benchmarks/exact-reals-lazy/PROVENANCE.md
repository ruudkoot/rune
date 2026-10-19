# exact-reals-lazy provenance

Finite series evaluation: lazy.

## Algorithm and workload

Represent a constructive real by a function from requested binary precision to
an arbitrary-precision integer approximant. Evaluate the left-associated sum of
sin(i*pi), i=1..n, and render forty decimal places. The result is zero, but the
port performs the source exact arithmetic, range reduction and power series.
Nonzero scalar reference cases independently exercise its arithmetic.

## History, authorship, revision and notices

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/exact-reals/Main.hs,
Makefile and exact-reals.stdout. The header credits David Lester's 2012 paper,
[The world's shortest correct exact real arithmetic program?](https://doi.org/10.1016/j.ic.2011.09.004),
Information and Computation 216, pages 39–46. Preserve the complete program and
fixture. These files state no separate redistribution notice. The suite retains
the established exact-reals name and gives meaningful evaluation variants
explicit lazy/strict suffixes.

Selected GHC base sources are pinned at 00920f176b0235d5bb52a8e054d89a664f8938fe.
Full base/LICENSE and the Ratio, Enum, List and Foldable sources preserve their
own notices. Their scope does not confer a notice on Lester's program.

## Evaluation, representation and translation

CR remains a precision-to-IntInf function. Function results are not memoized by
precision. Multiplication shares its two bound calculations within the CR value;
reciprocal repeats its precision search on every function call, as written.
Top-level pi, pi/2, pi/4 and sqrt(1/2) constructions and infinite coefficient
streams are memoized. Constants store CR functions, never precomputed answers.

The lazy policy suspends finite coefficient/power lists and their heads, stopping
at the first zero rounded term without forcing the unused tail. The strict policy
constructs those selected finite lists and evaluates their heads eagerly. Infinite
coefficient streams remain delayed in both. This policy deliberately exposes
otherwise unused series terms; the algorithm, bounds and requested precision stay
the same. No infinite list is made eager.

Keep the source left-associated sum. GHC.List/Foldable's list sum uses a strict
left fold; each CR addition still stores a function and requests two extra guard
bits from its operands. Reassociating or balancing the sum would change both work
and precision propagation. Enum CR uses the source default integer enumeration:
fromEnum evaluates at digitsToBits(40)=137, rounds to an integer, and toEnum
constructs each exact integer CR. The endpoints are not replaced by an unchecked
host loop convention.

Reuse the portable exact ratio operations shared with SCS. They follow GHC's
cross-product/reduction rules using IntInf, including normalization and gcd.
Each floor-square-root improvement constructs and normalizes its source ratio
before floor division. Rounding is floor(rational+1/2), with ties toward positive
infinity, including negative half integers. It is independent of host Real.round.
Only digitsToBits uses binary64 log/ceiling, yielding 137 for the selected forty digits. Full scalar and rendered
references are checked on every host. All integer precision counters fit signed 31-bit; arbitrary
precision intermediates retain IntInf.

Implement the source sine, cosine, atan branches, range reduction and square-root
path needed by this workload and auxiliary checks. Unused logarithm, exponential,
hyperbolic, reading and instance methods are omitted from the SML kernel; the
complete original remains. Finite SML strings replace Haskell output lists.
Read/validate arguments once per run, construct a fresh summation and compare
every rendered character with the forty-zero result before accepting it.
Coefficient/constant sharing persists across repeated in-process calls, as source
top-level definitions do; final sums are not cached. No runtime feature is added.

## Inputs, validation and calibration

| Profile | Summation endpoint | Origin |
|---|---:|---|
| smoke | 1 | small complete sum at unchanged forty digits |
| normal | 10 | calibrated complete sum at unchanged forty digits |
| large | 60 | original FAST_OPTS |

Upstream NORM_OPTS=350 and SLOW_OPTS=800 remain documented and available in
original reference evidence, but are not the suite normal/large choices. An
initial Rune stack pilot at endpoint 60 reached its 600-second limit before
finishing the lazy case; the combined pilot never started strict mode. This
records a time limit, not a wrong result. Endpoints 1 and 10 validate on both
policies at full precision. Large keeps the default 3600-second/8-GiB limit;
whole large SML validation is only claimed where separately recorded.

Rune's current IntInf library uses portable base-2^30 limbs and quotient-limb
search. This exact-rational workload is much more expensive there than on native
hosts with different big-integer implementations. Reducing digits, replacing
ratios with unchecked division or changing the summation would alter the workload;
they are not calibration changes. Profiles change n only.

Original GHC executions at 60/350/800 match the complete shared zero fixture.
Export-only observers record their 137-bit integer approximants as zero.
Fourteen scalar cases (pi, signed thirds, sqrt(1/2), trigonometric values and atan
across its branches) supply 84 exact integer approximants at six precisions and
14 forty-place texts. Both policies must match these source outputs exactly.
An independent 120-decimal-digit mpmath calculation checks integer error <=1
scaled unit and text error <=5.1e-41; this is a numerical cross-check, not a formal
proof. No floating tolerance replaces the primary exact output comparison.

Auxiliary tests cover half-integer rounding, first-zero stopping, unused inputs,
shared multiplication bounds, repeated reciprocal searches, left-addition
precision, small integer square roots, enum endpoints and the empty sum.
Primary smoke/normal matrices and counts use the manifest. Raw evidence and
validation scopes are recorded separately in validation.md.

## Compiler/runtime diagnostic questions and literature

Investigate arbitrary-precision arithmetic, gcd/normalization, function closures,
guard-bit propagation, coefficient sharing, early series termination, finite
eager evaluation, allocation lifetimes and whole-program specialization.
These are source-based hypotheses, not measured causal explanations. The common
SML program is the compiler comparison; original Haskell is a correctness
reference. Tiny or single-sample native runs are adapter diagnostics.

Lester's paper supplies the constructive-real algorithm and its error argument.
[Partain](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies suite context.
The pinned original and base sources supply the specific definitions translated
here; the independent high-precision check does not establish universal correctness.
