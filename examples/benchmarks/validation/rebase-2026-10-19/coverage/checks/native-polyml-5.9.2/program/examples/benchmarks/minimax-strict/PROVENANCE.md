# minimax-strict provenance

Finite data evaluation: strict.

## Algorithm and workload

Play the original tic-tac-toe game from a board with O at row 1/column 2 and X
at row 2/column 2. Generate moves in row-major order, alternate maximizing and
minimizing players, build alternating game trees, prune at depth five, map the
source static score, crop winning nodes and evaluate by a right fold. Retain
first-board tie breaking. Play until a win or a full board. Maximizing/minimizing
players remain function arguments through selection and recursive evaluation.

## History, variants and notices

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/minimax, all six
Haskell modules and Makefile. No author or individual redistribution notice is
stated in those files. Complete originals remain. The established minimax name
gets lazy/strict suffixes for material finite evaluation variants. It is not
combined with other game/search workloads merely because they use similar ideas.

The original driver takes one decimal string as both repetition count and prog
input. Every selected string chooses the same test board; only the impossible
driver string "doesn't happen" takes its six-row branch. Preserve that branch
and its subsequent pattern failure in auxiliary tests.

## Demand, data and portable translation

Use the same nested finite board/row lists and immutable piece values. Replacing
a piece reconstructs the complete three-cell row and three-row board, retaining
unchanged cell/row references. Game trees retain separate repetition, pruning,
mapping, cropping and evaluation stages rather than a direct recursive solver.
Static scoring keeps the eight winning-mask order and cumulative nonwinning
scores. The full-board test retains its mapped Boolean list. Position
comprehensions construct fresh delayed row/column enumerations per call. Winning constructors short circuit the right fold in lazy mode.

The lazy variant memoizes finite list spines/heads, tree roots and payloads.
Depth-zero pruning avoids generating children; cropping a winning node inspects
the child spine but avoids its head. The strict variant eagerly constructs these
finite values, including the complete unpruned tree before the depth-five cut,
and evaluates fold tails before a winning first value can discard them. All
trees are finite as moves consume empty squares. A counted linear-tree probe
distinguishes zero child expansions at lazy depth-zero pruning from four eager
expansions. This substantial work/allocation difference is deliberate.

Inclusive index loops become finite lists. Bounded scores, indices, repetition
counts and selected output lengths fit signed 31-bit int. No optional runtime
facility is used. The source printed result is the complete 194-character game,
including five XWin evaluations, but Main only forces length(prog input) and
prints nothing. The SML driver fully renders and checks every character against
a reviewed fixture, then reports repetitions:total-character-count. SML string
construction and complete validation are added costs compared with lazy
character-spine length consumption.

Each repetition constructs a fresh board/tree/game. Original compilers may share
the invariant prog result inside their loop; the port does not precompute a
repeated-run answer. Original Haskell runs supply correctness references, while
comparative timing uses the identical SML on all hosts.

## Inputs, validation and literature

| Profile | Complete fresh games | Origin |
|---|---:|---|
| smoke | 1 | bounded repetition count, original board/depth |
| normal | 100 | bounded repetition count, original board/depth |
| large | 1000 | scaling repetition count, original board/depth |

Original FAST/NORM/SLOW counts 180000/1800000/9000000 remain in Makefile and
provenance. The selected counts accommodate fresh reconstruction and the eager
variant while retaining the complete game and depth five. Default limits apply.
Both normal Rune O2 pilots validate all 100 games under their recorded guards;
larger coverage is claimed only for separately recorded runs.

Unmodified GHC runs produce empty stdout as expected. An export-only observer
records the full game and seven immediate static scores. A separate Python
position evaluator agrees on that complete game and eleven varied board
analyses, including both wins, ties and first-winning-mask behavior. GHC confirms
all eleven complete static/max/min analyses. SML tests also cover repetition,
wrong-character rejection, occupied squares, stable ties, invalid board shape,
prune/score demand and eager construction.

[Partain](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies nofib context;
the preserved Board/Game/Tree/Wins/Prog modules define this particular heuristic,
tree depth and evaluation order. They are source evidence for diagnostic
questions about closures, sharing, short circuiting, tree allocation, higher-order
folds and specialization. No measured causal explanation is asserted.
