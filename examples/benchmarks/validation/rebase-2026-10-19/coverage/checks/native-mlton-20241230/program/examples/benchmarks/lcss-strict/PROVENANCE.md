# lcss-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/lcss/Main.hs`. Andrew J. Bromage contributed this
Hirschberg longest-common-subsequence example in November 2002; the original
mail/header is retained. It explicitly discusses quadratic time and linear
space assuming eager evaluation. An individual licence is unspecified, recorded
as a gap. Source, Makefile and fixtures retain their SHA256 identities.

Preserve row-pair updates, forward/reversed score rows, integer middle split,
last-maximum tie selection (>=), and difference-list result composition. The
lazy variant memoizes row values/spines, reverses cells without forcing their
values and delays the recursive result suffix so left output does not force the
right subtree early. The strict variant computes finite row lists and eager
recursive results. This changes evaluation/retention while preserving the
algorithm, arithmetic and selected sequence. No array-based or alternative LCS
kernel substitutes for the original list-pair algorithm.

The driver preserves six arithmetic-sequence parameters. Nonzero step and a
nonempty first sequence are required: the original missing empty-first case is
not silently repaired. Selected inputs fit machine integer widths. Profiles
are (1,2,16;8,9,24), (1,2,200;100,101,400), (1,2,2000;1000,1001,2000); large
preserves original FAST. Original NORM/SLOW and heap flags remain recorded.
The complete returned list is consumed and checked, not just its length. Original
GHC output agrees with an independent dynamic-programming oracle and the unique
ascending intersection for these profiles. SML materializes the result prefix
for full validation; output becomes its actual length. Large SML execution is
not universally claimed.

Row sharing, retained deferred values, repeated prefix traversal, higher-order
composition and compiler specialization are source-derived performance questions
until measured. The strict/lazy distinction is material to the source's space
claim. References: original Bromage explanation, its Hirschberg attribution and
the nofib survey; no broader mathematical or timing claim is inferred from one
input family.
