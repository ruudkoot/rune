# scc-lazy provenance

Memoized variant; its strict companion retains the same algorithm.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/scc/Main.hs`
and `Digraph.hs`. The main header credits John Launchbury and identifies the
fixed graph as Figure 6.4 of SLPJ 1987. Original Haskell, historical Miranda
support source, Makefile, stdout fixture and SHA256 identities are retained.
The individual licence notice is unspecified. The graph is defined in source;
no external dataset is acquired.

## Algorithm and variants

Preserve the two DFS passes, list-based visited membership, edge-list scanning
for each adjacency range, reverse edges, finish-list concatenation and exact
component/member order. No array adjacency table, hash set or different SCC
algorithm substitutes for this implementation. Haskell's first traversal
produces a visited list and a lazy accumulated finish list; the second builds
components in reverse discovery order. SML memoizes both tuple fields and each shared recursive result, so finish
heads can be consumed before the last visited subtree is demanded. Finish-list
spines/heads remain memoized in the lazy variant. The strict variant eagerly builds those finite lists. Both share
one functor and retain separately named implementations.

## Translation, inputs and validation

SML97 int is sufficient for the seven original vertices. BenchCellSequence
represents finish/component list demand; known input edges and visited nodes
remain ordinary lists. Preserve the original graph in smoke and normal, each
with one kernel invocation. This is a small fixed diagnostic whose fresh-process
measurements include substantial startup cost. Large explicitly adds 10,000
repeated invocations of the same graph. Pure repeated work may be optimized or
hoisted by a compiler; this is a source-derived hypothesis, not an assertion of
steady state or enlarged-graph scaling.

The driver validates the complete component order against the original fixture
on every invocation and consumes actual rendered byte counts. Formatting,
fixture acquisition and checks are added costs. Original GHC matches the pinned
stdout fixture; independent mutual reachability validates the complete partition.
Nine checks cover the original order, disconnected vertices, cycles, duplicate
edges, unused finish-list demand, lazy tuple projections, recursive field sharing
and lazy/strict agreement. An initial test used
an incorrect expected partition/order; the reviewed correction and rejected
attempt are retained. Primary smoke/normal validation is recorded separately;
large SML execution is not universally claimed. References: [Peyton Jones, *The Implementation of Functional Programming Languages*](https://simon.peytonjones.org/slpj-book-1987/), Prentice Hall, 1987
(the source identifies Figure 6.4) and the nofib survey. Adjacency scans, finish concatenation,
visited membership and retained lists are hypotheses until measured. The initial
prototype produced correct complete results but demanded visited recursion too
early. Source inspection and the GHC demand observer led to the memoized tuple
projection correction before suite registration. Intermediate results are
distinguished from final source validation.
