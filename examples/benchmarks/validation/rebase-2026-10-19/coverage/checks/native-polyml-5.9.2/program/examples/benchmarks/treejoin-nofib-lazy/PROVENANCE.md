# treejoin-nofib-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/treejoin`.

Complete pinned sources, build parameters, input/output fixtures and SHA256
identities are retained. Individual licence notices remain unspecified where
not present in source. Kernels and shared translation support are SML97.
Source inspection explains the following behavior; performance sensitivities
remain hypotheses until measured. Large SML execution is not universally claimed.

## Algorithm, history and variants

The complete tree algorithm agrees with the GC treejoin source; the spectral
variant repeats 100 times and uses shuffled relation files 1500/8000/27000.
These are materially different input shapes from the monotone GC datasets.
Share the reviewed lazy boundary-tree implementation, while retaining
all original files, stopping conditions, notices and naming. The individual
spectral author is not stated; the related GC 1993 mail remains separate evidence.

## Translation, inputs and validation

Preserve unbalanced persistent insertion, key boundaries, third-left/first-right
join lookup, duplicate rules and right-before-left accumulation. Lazy fields and
branches remain memoized; strict fields/updates remain eager. Every repetition
reads the fixed relation files and validates all five result fields, adding
rendering/reference-check work to the original forceTree unit output. The reported
record/match counts are consumed. Smoke uses the first 125 records of both 1500
files once; normal preserves complete 1500 files 100 times; large preserves 8000
files 100 times. Original27000/SLOW remains available. Numeric fields fit 31 bits.
Original GHC full-state observers and independent relational dictionary joins
agree with complete sorted fixtures. Input byte strings replace lazy file lists,
with that materialization/retention change documented. Shared-versus-eager tree
paths, shuffled insertion depth and join selectivity are hypotheses until measured.
References: retained source, related submission history and nofib survey.
