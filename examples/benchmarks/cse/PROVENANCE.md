# cse provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/cse/Main.hs` and StateMonad.hs. Mark P. Jones,
1992. The source's history/explanations and example diagrams are retained; an
individual licence notice is unspecified. Source/build identities are recorded.

Preserve the pure state-function representation s -> (s,value), bind/map-list,
left-to-right preorder labels, tree-to-graph conversion, right fold over the graph,
closure-based label renaming and first matching equivalent subtree selection.
No mutable label counter or hash-consing algorithm replaces the source's state
and association-list operations. Complete graph labels, symbols and child-label
lists agree with original GHC and independent bottom-up subtree interning.
The SML state tuple is explicitly closed for portability across the hosts.

The original six expression examples are retained. Main selects take(i mod6)
for i=1..n, so the sixth example is never selected by the timed loop; this
stopping behavior is preserved, while all six golden graphs are independently
reviewed. SML eagerly represents the small input trees/lists; all selected output
graphs are fully forced as original rnf requires. Added full-graph rendering and
validation replaces discarded unit outputs, and actual node totals are consumed.
Unused pretty-printers/unGraph helpers are retained in the original but not added
to the runnable kernel. The added check work is included.

Profiles use6/120/30000 iterations; large preserves original FAST, and original
normal300000/slow1500000 remain in Makefile. Large execution is not universally
claimed. Closure specialization, state tuple representation, label renaming and
shared graph objects are source-derived hypotheses until measured. References:
original Jones explanation/example graphs and nofib survey.
