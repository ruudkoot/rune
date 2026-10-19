# fibheaps-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/fibheaps/Main.lhs`.
Chris Okasaki's July 1995 correspondence says he translated the example from
SML and tested it in Gofer. Original correspondence, literate implementation,
Makefile, other retained source fragments, stdout fixture and SHA256 identities
are preserved. Individual licensing is unspecified. Inputs are generated in
source; no external dataset is acquired.

## Algorithms and variants

Keep heap-ordered binomial trees, degree tags, size and cached minimum tree,
Empty/Cons/Union bag forests and foldr insertion/meld. Link ties use <= and keep
the left root; children carry descending degree tags. Forest apply traverses
Cons in forward order, while bag flattening reverses Cons order. Keep both
consolidation algorithms in their original comparison: a mutable degree array
with carry links, and accumArray-style degree grouping followed by functional
links and minimum selection. The port uses existing SML97 Array for the
encapsulated mutable operations and degree grouping.

The memoized variant retains delayed tree/heap fields and output spines. The
strict variant eagerly evaluates the same finite structures. Functional
consolidation is delayed behind shared minimum/forest projections; demanding
its heap header does not build the array. Mutable consolidation performs its
array scope before yielding the header. Both variants share one functor and
still compare the two deletion algorithms. Constructors, explicit memo cells,
portable array operations and sequence traversal are representation/library
adaptations. Used keys and indices are specialized to int.

## Inputs, result checks and runtime questions

The original normal count is 300,000. Smoke uses 100, paired normal uses 30,000
and large retains 300,000. The strict -O0 original-size pilot exhausted its
4 GiB limit; the memoized pilot passed. The smaller shared normal profile passes
its bounded strict preflight and keeps comparative inputs identical. This
stopping-parameter change and memory failure are recorded. Large SML execution
is not universally claimed.

Preserve the first seed 1967, then (77*seed+1) rem 1024. Keys after the first
lie in 0..1023; selected arithmetic, counts and sums fit 31 bits. The driver
interleaves both sorted outputs as the original equality does, additionally
checking ordering, a reviewed independent histogram, consumed length and sum.
Checking/reference acquisition costs are explicit. Original GHC observers
agree with independent histograms for all selected profiles. A separate GHC
observer verifies the distinct consolidation demand boundaries.

Nine semantic checks cover RNG prefixes, both algorithms, memoized/strict
agreement, empty/singleton heaps, forest orders, ties and delayed versus demanded
consolidation. The source discusses amortized use and retained expensive versions.
Current tree/bag sharing, array lifetimes, degree carries and strict output
retention are diagnostic hypotheses until source/IR analysis and measurements
establish them. References: retained Okasaki correspondence and
[Fredman and Tarjan (1987)](https://www.cs.princeton.edu/courses/archive/fall03/cs528/handouts/fibonacci%20heaps.pdf),
plus the shared nofib/GC/measurement survey. The source's functional heap subset
and consolidation comparison remain distinct from the paper's broader heap API.
