# last-piece-lazy provenance

Selected evaluation: lazy candidates, remaining-piece inputs and solution tree.

## Algorithm and workload

Tile the fixed 8x8 board using the source's sex-constrained piece orientations.
Start with the three-square a piece, scan row-major from (1,2) Female, choose a
remaining piece/orientation, fit it into a persistent board map, and recursively
construct Soln/Choose/Fail search results. Render every solution in source order.
The full puzzle has three solutions; retain the exact piece data and ordering.

## History, revision, authorship and dependencies

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798,
spectral/last-piece/Main.hs, Makefile and last-piece.stdout. The header credits
Simon Peyton Jones, May 2002. It states no separate redistribution notice;
retain the original without inventing a grant from another component.

Original GHC 9.4.7 uses containers 0.6.7 and pretty 1.1.3.6. Pin containers at
9f4a93604c66a5e605ce46fc30003b71802b3cfd and pretty at
c3a1469306b35fa5d023dc570554f97f1a90435d. Retain complete selected source files,
package versions and BSD-style notices. Map source credits Daan Leijen and
Andriy Palamarchuk; the rendering module credits Glasgow and the Hughes/
Peyton Jones design. The explicit last-piece-lazy/strict names preserve
meaningful search-tree evaluation variants.

## Source ordering, preconditions and variants

pickOne reverses the skipped prefix: choices for [a,b,c] leave [b,c], [a,c],
then [b,a]. Do not replace it with the usual stable-order deletion. Orientations
retain their exact order and share the remaining-piece thunk for one piece.
Fitting checks offsets first and inserts the anchor last without another bounds/
occupancy check. Source search establishes that anchor precondition; direct fit
is not silently strengthened. Row transitions and occupied squares flip sex
exactly as written. Selected offsets keep rows positive, so the source's absent
lower-row guard is not added.

The lazy variant memoizes candidate/result spines and solution children, fitting
one candidate before demanding its recursive search. Rendering visits all
solutions/failures in the source order. The strict variant constructs finite
candidates and the complete result tree eagerly, retaining the same board-map
algorithm and output. Both agree on full outputs; their temporary allocation,
retention and evaluation timing differ.

## Portable SML translation

SML97 keeps the size-balanced persistent map with cached subtree sizes,
delta3/ratio2 and the source's specialized balanceL/balanceR rotations. Every
insertion-prefix shape agrees with original containers on four 64-key traces.
It is not replaced with an AVL or mutable occupancy array. Native pointer-
equality insertion shortcuts are omitted: benchmark insertions use fresh keys,
so those early returns cannot occur. General replacement values preserve map
contents/shape without claiming identical pointer-identity optimizations.

Board keys, offsets, sizes and counts fit signed 31-bit Int. Piece identifiers
are the original ASCII characters. Remaining-piece and orientation lists retain
their values; candidate/result nodes and shared remaining lists use explicit
memoized delays where needed. Immutable piece data/initial board may be shared;
each solve call reconstructs the result tree, preventing previous solutions
from being reused as a repeated-run result cache.

The used-domain renderer replaces the external pretty library with portable
SML emission. Fixed board lines fit width200 and ribbon ratio1.5; no wrapping
alternative is exercised. Preserve Success!, reverse row display, two-space
nesting, indented blank lines and the final newline, including empty-result
behavior. This is not a claimed port of every general pretty API. Full byte/EOF
checking and reference I/O replace stdout and are measured work. The driver
reports remaining:solutions:bytes only after complete validation.

## Profiles and diagnostic questions

Smoke leaves the last two source pieces and preplaces the others from the first
reviewed original solution. This is a valid subproblem through the original
search API, with the same board size, initial a, sex and orientation rules.
Normal preserves all 13 remaining pieces and the original three solutions.
An eight-piece subproblem is also retained as a correctness reference. The
fixed original board is already the maximum source instance, so no artificial
large profile is introduced; the harness still supports explicit repeated mode.
The driver bounds remaining pieces to 0..13. SML generates runtime board inputs
from exact embedded data; no external dataset or input-generating interpreter
is required.

Source-based questions include map rotation/allocation, failed fits, reversed
choice order, memoized search, eager result retention and rendering/check costs.
These remain hypotheses until source/measurement evidence establishes effects.
Standard reports compare identical SML. No parallelism, FFI, effects or compiler/
runtime feature is required.

## References and validation

The unmodified original's complete 300-byte output matches the pinned fixture.
Original prefix calls and an independent bitmask/reversed-choice model agree on
all boards and exact output for 0/2/8/13 remaining pieces. The full model visits
103513 search states and finds three solutions; original tree statistics agree.
Every board covers all 64 squares. The smoke/normal inputs are not fabricated
by merely dropping pieces from an empty board.

Tests cover 256 complete map-prefix shapes, initial board, reversed pickOne,
shared/delayed remaining pieces, unforced child search, source fit preconditions,
complete prefix outputs/statistics and changed/truncated/extra output rejection.
Both SML variants reproduce the full original output in bounded preflights.
Large or other configuration validation is claimed only where recorded.
Pinned source and dependency explanations provide the exact implementation
reference; the shared nofib/measurement literature supplies context without
claiming a measured performance cause for this translation.
