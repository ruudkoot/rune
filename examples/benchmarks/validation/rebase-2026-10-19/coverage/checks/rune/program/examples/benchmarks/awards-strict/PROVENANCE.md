# awards-strict provenance

Strict variant; its memoized companion retains the same algorithm.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/awards/Main.hs`
and `QSort.hs`. Kevin's June 1995 submission is retained with its
`kh@dcs.gla.ac.uk` attribution; QSort credits Lennart Augustsson. Preserve both
sources, Makefile, boot script, original output template and SHA256 identities.
Individual licence notices are unspecified. The source explicitly identifies
its four competitors' data as fake.

## Algorithm and variants

Preserve ordered three-element combinations (despite the source function name
perms), shared total/triple pairs, Gold/Silver/Bronze thresholds 70/60/50,
inclusive threshold tests and lexicographic sorting by (total,triple).
Select the first available tier and its smallest sorted qualifying total,
then remove each used score's first occurrence and recurse. Do not substitute
maximum-score awards or a search for the globally optimal award combination.

Keep Augustsson's six-function stable/anti-stable quicksort structure with
reversed partition lists, accumulated suffixes and no concatenation in sorting.
The lazy variant memoizes list cells, candidate heads, totals and sorted suffixes;
all three award tiers share the same sums. The strict variant eagerly evaluates
these finite lists. Both share one SML97 functor. Score triples are finite
ordinary integer lists; all selected scores/totals fit 31 bits.

## Translation, inputs and validation

Keep the original i mod 100 input distribution and competitor lists. Smoke uses
one source iteration; normal uses FAST 2,000 and large uses NORM 20,000.
SLOW 100,000 remains recorded and supported by the checked argument. Replace
printing each result by complete per-iteration validation against a reviewed
100-input cycle and accumulated actual byte counts. Formatting, cycle-file
loading and checks are included costs.

Both variants' complete 100-input output agrees with original GHC and an
independent combinations/sort/greedy-removal oracle. The pinned FAST output
template equals the cycle repeated 20 times. Nine semantic checks verify
combination order, stable sorting, deferred versus eager suffix demand,
threshold inclusion, duplicate score removal, tier/minimum-total priority and
all input-cycle variant results. Large SML execution is not universally claimed.
References: retained Kevin submission, Augustsson QSort explanation and nofib
survey. Candidate generation, shared totals, discarded award tiers and unused
sorted suffixes are source-derived hypotheses until measured.
