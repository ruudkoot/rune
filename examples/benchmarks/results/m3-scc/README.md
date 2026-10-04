# m3-scc validation

Recorded 2026-10-04. The two list-based DFS passes preserve component/member order, lazy tuple
projections and shared recursive results. Original GHC matches the pinned
fixture; independent mutual reachability verifies the full partition. A GHC
demand observer confirms a finish head can precede the last visited subtree.
Nine semantic checks pass all ten configurations at both levels. Earlier
prototype results are intermediate evidence. Normal retains the single original
graph invocation; startup costs are substantial. Large is not universally checked.

[All 48 final primary cases](correctness.tsv) pass smoke/normal
on four Rune engines at both optimization levels and four managed native hosts.
The final matrix compiles canonical suite paths, source order and inputs.

Count archives retain complete samples, source/input/tool snapshots and
configuration identities. Allocations and applicable instruction comparisons
agree. Instrumented times are not headline timing evidence. Initial resolver
races are retained in [the tooling record](../m6-resolver-isolation/README.md).
