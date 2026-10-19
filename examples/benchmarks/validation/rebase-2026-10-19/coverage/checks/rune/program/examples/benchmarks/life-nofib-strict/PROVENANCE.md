# life-nofib-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/life/Main.hs`.

John Launchbury is credited in the Game of Life header. The individual
licence notice is unspecified; original source, Makefile and SHA256 identities
are retained. This is the finite list-grid and adjacent-generation equality
variant, separate from the classic array/list Life programs and their inputs.

## Algorithm and variants

Preserve the original initial pattern on row 14, square clipping/padding,
zero border, shift triples, eight-neighbor sum and Conway update rules.
The adjacent-fixpoint test stops at the first equal pair and returns the older
board. Its generation index and exact display formatting are preserved.
No cycle detection or different stopping condition is substituted.
Both variants share one algorithm and sequence abstraction. Lazy heads/spines,
row values and neighbor cells are memoized; strict materializes them eagerly.
The old center cell remains unforced for birth/death and is read only for
survival with exactly two neighbors, as in the source.

## Translation and runtime questions

SML97 suspension adapters represent the original lazy list grid. Nested row
indirections and explicit memo cells affect representation/allocation. Input
generation remains in SML; integer cell values and selected indices fit 31 bits.
The program additionally checks the complete final display, consuming every
repetition in a sum of actual display lengths. The original prints only length
of that final display; intermediate generations remain undisplayed. Primitive
source/shift order, shared neighbor work, early equality exits and grid retention
are source-derived diagnostic questions until measured.

## Inputs, validation and references

Smoke uses original FAST size 15 once, with a nonempty initial pattern. Normal
retains FAST 15 with 250 repetitions; large retains NORM 27 with 250. SLOW 29 remains
recorded. Source fixpoint indices are 0/5/49/181 for sizes 5/15/27/29, with display
lengths 58/468/1489/1716. Original GHC observers and an independent synchronous
array-grid oracle agree with the complete final displays. All selected final
boards are empty, but the nonempty inputs undergo the recorded generations.
Semantic tests cover a two-step blinker, exact stop indices and center demand.
Primary smoke/normal cases pass; large SML execution is not universally claimed.
The paired semantic test triggers ML Kit's CompileDec.TypeFcn not simple crash;
that compile failure is recorded separately, without a source workaround.
References: retained Launchbury implementation and the nofib literature survey.
