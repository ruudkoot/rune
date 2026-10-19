# puzzle-strict provenance

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/puzzle/Main.hs
and Makefile. The header says the brute-force solution was sent by Stephen
Eldridge; it does not identify a separate author or redistribution grant.
Retain that distinction and the unmodified sources/identities. The embedded
Bono/Edge/Larry/Adam constants are program data, with no acquired dataset.

## Algorithm and variants

Search backwards from all four people on the right bank to all on the left.
Enumerate single crossings before pairs, in the source's item order. Preserve
crossing costs 10, 5, 2, 1 and pair cost of the first (slower) item. Reject states
already present in the prior history; the current destination is prepended to
newHistory separately. Do not replace this enumeration with shortest-path
search, torch-inclusive cycle pruning, or a predetermined solution.

Each branch returns a persistent history of countdown/state pairs. Scan every
solution, accumulate every equal minimum, and reverse the accumulator to retain
source order. Render the complete histories with the same labels, times,
spaces, borders and line endings. Need memoizes solution/history spines, heads
and countdown fields; Strict materializes the corresponding finite structures.
The four bank fields are atomic constructors in an eager immutable SML tuple;
record updates rebuild that tuple. Branch guards still control recursion.

The source's derived Eq/Enum become SML datatype equality and explicit item
successors/ranges. ShowS functions become ordered finite character sequences;
constant lines are shared. Decimal labels use Int.toString over nonnegative
values. The longest simple path has at most 15 crossings and total cost at most
150, so selected counters and summed byte totals fit signed 31 bits.

## Inputs and observation

Smoke 2, normal 16 and large 80 preserve FAST/NORM/SLOW repetition counts.
The original reads the same command arguments inside each repetition and sets
time to zero after confirming exactly one argument. The portable driver reads
and validates arguments once, starts each search with zero and reads its reviewed
result fixture once. Original forcing consumes every rendered character and
emits no output; the suite compares every character and sums checked bytes.
The final result reports repetitions:total-bytes. Validation and fixture I/O
are observable additions. No search result is substituted by its known length.

Original GHC runs complete all three profiles. An export-only observer finds
21,924 solutions and two ordered minima of 17, rendering 2,794 bytes. A separate
bit-state enumeration agrees on the complete solution-time histogram, ordered
minimal histories and every rendered byte. An independent Dijkstra traversal,
which includes torch position and omits history pruning, confirms the global
minimum. This reference traversal does not replace the benchmark's algorithm.
Semantic checks cover these results, complete minimum scanning, equal-order
stability, unused times/tails, shared countdowns, empty output and perturbations.
Large execution of the SML ports is claimed only where explicitly recorded.

## Diagnostic questions and references

The retained program is the benchmark-specific algorithm/history reference;
Partain's [nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies
suite context. Search branching, tuple equality, persistent-history sharing,
streamed versus retained solutions, allocation lifetimes, min accumulation and
formatter specialization are source-based questions until supported by compiler
inspection or measurements. Standard comparisons use identical SML. Haskell
and the independent traversals supply correctness references.
