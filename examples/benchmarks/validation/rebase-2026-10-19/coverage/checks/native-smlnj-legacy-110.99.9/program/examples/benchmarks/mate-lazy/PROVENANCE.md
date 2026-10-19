# mate-lazy provenance

### Algorithm and workload

Search the source AND–OR chess end-game tree to depth 2*N-1: select the first
winning attacking move, then prove a winning continuation for every legal reply.
Retain list-based boards, legality checks, line-move continuations, source move
order, pawn promotion and king threats. The program's move rules omit castling
and en passant; do not substitute a different full-chess engine. Compact equal
printed reply subtrees and print the source descriptive notation and ordering.

### History, authorship and data

The pinned [nofib mate source](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/mate) is revision
b7391df4540ac8b11b35e1b2e2c15819b5171798. README describes AND–OR search and a
historical nhc98 timing example. No individual program author is stated in its
five Haskell modules or README. Preserve all originals, puzzle data and historical
solution files under mate-lazy/upstream. The README's 2017 fixture note predates
the current FAST/NORM/SLOW Makefile selections; use the pinned manifests and
actual runs as evidence rather than assuming that note is current.

Puzzle comments declare individual composition history: G. Heathcote's Reading
Observer problem (1904), Kohtz and Kockelkorn's Schachaufgaben problem (1875),
and the Holzhausen problem, plus other retained composers/dates. Preserve each
input's comments and notices; do not treat a puzzle composer as program author.
The simple problem's comment describes a castled king trapped behind pawns.
New tiny validation positions are generated deterministic test data, separately
identified by cases.py. No separate dataset redistribution notice is stated in
these puzzle headers; retain the complete pinned files and suite provenance.

### Variants and portable translation

-lazy uses memoized board-list spines, move generation and result trees with
source short-circuiting. -strict additionally materializes each position's finite
legal-move list eagerly; it does not exhaustively evaluate the whole search tree.
Both retain attacking disjunction and defending conjunction stopping rules.
They must agree on the selected move and complete printed solution. Each
Benchmark.run starts the source computation from its input; no cross-call result
cache is added.

Keep persistent board removal/insertion and source ray/sift ordering. Explicit
callbacks preserve moveLine's difference-list continuations. Preserve default
constructor order for pieces, moves and promotions. Compaction compares printed
subtrees; the stable natural mergesort used by the source Data.List.sortBy is
translated with its run detection and equal-key ordering. The foldr attacking
selection is exposed as choose for a negative demand test; it uses the same
move stream and source search rules. Portable pair type annotations resolve
record selectors on all SML hosts without changing representations.

Read the fixed problem and reviewed expected text once per run. Materialize the
bounded final textual report before comparison, replacing repetitive stdout;
record this output buffering/validation adaptation separately from the search.
The source parser's comments, ranks, piece colours and goal convention remain.
All board coordinates, depths and selected problem counts fit signed 31-bit
integers; no arbitrary-precision or floating-point arithmetic is needed.

### Inputs, profiles and exact validation

Smoke selects upstream runtime_files/simple.prob, a one-move problem. This is an
explicit smaller source problem than FAST's three-move heathcote3.prob, whose
full output is also validated in private calibration and reference fixtures.
Normal retains runtime_files/kohtz.prob; large retains
runtime_files/holzhausen.prob. The timed program processes one named problem,
not a synthetic universal size parameter. Preserve the relative runtime_files
path because the original File header includes it.

Compare the complete source output byte for byte and report its checked length:
212 characters for smoke, 374 for normal and 2159 for large. There is no numerical
tolerance. Original GHC 9.4.7 matches all published FAST/NORM/SLOW fixtures.
The selected smaller smoke has its own original complete output. Historical
.soln files can use older notation and are retained as provenance rather than
silently promoted to current exact expectations.

The 48-check target compares nine original legal-move/updated-board fixtures and
six small solutions, verifies promotion choices, stable sorting, constructor
order, persistent boards, unused-opponent demand and a winning alternative's
unforced tail, and rejects incorrect output. These controls distinguish intended
search pruning from accidental evaluation. Earlier draft demand probes and
relative-path/type-annotation failures remain development evidence, not reported
compiler bugs. See the recorded validation for actual host configurations and
profile limits. Full large SML runs are claimed only where explicitly recorded.

### Literature and diagnostic interpretation

[The source README](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/mate/README) describes this particular AND–OR workload;
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) provides suite
context. The puzzle headers supply their historical references. Do not infer
alpha–beta pruning, transposition tables or a chess-correctness theorem from a
generic game-search literature citation: these facilities are absent here.

Investigate persistent board traversal, short-circuit search, eager legal-list
allocation, continuation specialization, repeated printing during compaction and
stable sorting. These are source-based diagnostic questions. Exact agreement
with original outputs establishes results for the selected inputs; timing/count
records are measured evidence and do not alone identify performance causes.
