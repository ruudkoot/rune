# lcss-nofib-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/lcss`.

Complete pinned sources, build parameters, input/output fixtures and SHA256
identities are retained. Individual licence notices remain unspecified where
not present in source. Kernels and shared translation support are SML97.
Source inspection explains the following behavior; performance sensitivities
remain hypotheses until measured. Large SML execution is not universally claimed.

## Algorithm, history and variants

Andrew J. Bromage's November 2002 submission describes Hirschberg's algorithm
and its eager O(N) space behavior. The spectral and GC bodies agree exactly;
this driver reuses the reviewed lazy GC kernel rather than adding an algorithm
copy. The spectral program repeats 500 times and prints full sequences, while
the GC driver computes once with larger input ranges. Both sources and names
remain. Preserve last-tie split selection, row-pair layout, difference-list
composition and sequence generation.

## Translation, input and validation

The lazy variant memoizes row values and result tails; strict materializes them.
The spectral driver invokes the same full-sequence validator per repetition and
returns the consumed sum of actual lengths. Smoke uses 1..20 and 10..30 once;
normal preserves FAST 1..60 and 30..90 with 500 repetitions; large preserves
NORM 1..200 and 100..300 with 500. SLOW 300/150..450 remains recorded. All values
fit 31 bits. Original GHC's500 outputs agree with independent ordered intersections
for these monotone unique sequences; previously reviewed general LCSS tests cover
ties/duplicates and lazy suffix demand. Row allocation, sharing, retention and
repetition costs are hypotheses until measured. References: retained Bromage
submission and the shared LCSS provenance/literature survey.
