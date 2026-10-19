# typecheck-strict provenance

### Algorithm and workload

Infer polymorphic types for the source's eight fixed functional programs:
recursive ones, length, map, SKK, increment, sum, recursive Y and succ. Preserve
unification with occurs checking, scheme instantiation/generalization, recursive
bindings, deterministic split name supplies and printed type variables. The succ
case reports failure under the source algorithm. The original consumer sums
printed character codes and returns (sum+character-count)/character-count.

Substitutions remain callable name-to-type functions composed by higher-order
closures. Environments remain ordered association lists, with shadowing and
source lookup costs. Do not replace them with union-find variables, mutable
substitution tables or a host typechecker.

### History, authorship and naming

Source [nofib spectral/hartel/typecheck](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/hartel/typecheck), pinned at
b7391df4540ac8b11b35e1b2e2c15819b5171798. Preserve Main.hs, Makefile, all fixtures
and the parent Fast2haskell.hs under typecheck-lazy/upstream. No individual author
or separate program notice is stated in Main.hs. Collection-paper authorship is
context rather than evidence of individual program authorship. Names retain the
established typecheck workload and separate -lazy/-strict evaluation policies.

### Source details and portable adaptation

-lazy memoizes type constructors and finite children; -strict demands those
children when a type constructor is requested. Both preserve lazy expression,
environment, scheme and control structures where failure can leave work unused.
Names use bounded atomic SML strings rather than lazy character lists. Keep the
eight immutable input ASTs global, but add no cross-repetition inferred-row cache.
Each source repetition maps inference over the flattened program list.

Unification of equation lists proceeds right to left, as the source foldr;
it can skip an earlier equation payload after a later failure. Preserve source
zip truncation for mismatched constructor arities. Source noDuplicates reverses
first-occurrence order. Environment range maps first-match lookup over every
name, so shadowed duplicate names repeat the first scheme's unknowns. Keep those
behaviors rather than substitute customary library implementations.

Preserve name-supply splitting/depletion, the same scheme supply across a group
of declarations, function substitution composition and the source recursive-let
stages, including applying the next substitution to already substituted bounds
and environments. Fast2haskell's miraseq stub is a no-op; a generated strict
helper name is not proof of strict evaluation. These choices matter to structure,
sharing and printed type-variable names.

### Profiles and result consumers

Smoke uses one repetition instead of source FAST's 500. Normal retains 5000
repetitions and large retains 25000. Every repetition processes the original eight
ASTs and 239 printed characters. Preserve the original checksum, while adding an
exact comparison of each inferred row with the reviewed original rows before its
characters enter the checksum. The validation callback adds observable work and
is documented separately from the inference algorithm.

Original GHC 9.4.7 gives 14522/239 for one repetition,
72610000/1195000 for normal and 363050000/5975000 for large. Every selected counter
fits signed 31-bit integers; even a conservative ASCII upper bound for the large
checksum is 764800000. Driver counts are bounded to the selected range 0..25000.
No arbitrary-precision or floating-point arithmetic/tolerance is required.
The stable report retains the original checksum without its trailing newline.
Full final SML large repetitions remain unrecorded unless listed in validation.

### Validation and compiler behavior

Original GHC matches all FAST/NORM/SLOW fixtures. Export-only observers provide
all eight exact inferred rows, six further expressions and substitution/name/
generalization edge cases. Both ports reproduce the rows and original checksum.
Full normal private pilots also validate every row. The recorded optimized GHC
core retains the source mapping/checking pipeline; timings are not used as proof
of a particular optimization or memoization decision.

The 28-check target covers these observations, right-fold failure demand,
constructor-arity behavior, shadowed environments, occurs rejection, a skipped
later expression, memoized function substitution, quantified-variable exclusion,
zero repetitions and exact per-row validation. A deliberately changed int to nit
row has the same weak checksum and is rejected by the new validator. Native and
Rune O0/O2 canonical outcomes are recorded separately from development pilots.

### Literature and diagnostic interpretation

[Milner, A theory of type polymorphism in programming](https://doi.org/10.1016/0022-0000(78)90014-4)
(1978) supplies polymorphic-inference context; the pinned source defines this
particular implementation and ordering. No soundness theorem is inferred for
its source-specific arity/shadowing behavior.
[Hartel and Langendoen's collection paper](https://doi.org/10.1145/165180.165230)
(1993) supplies translated-benchmark context. Publisher/institution metadata and
abstracts were reviewed; this does not claim a full paper-derived proof.

Investigate higher-order substitution composition, repeated environment lookup,
type reconstruction, generalization, memoized fields, strict children and text
consumption. These are source-based questions. Exact original type agreement and
negative controls support correctness for the selected cases; measured counts
and times are distinct evidence and do not alone establish performance causes.
