# count-graphs provenance

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/count-graphs.sml`. Original, patch and notice retained.

Henry Cejtin graph isomorphism-class enumeration using permutation, subset
and graph folds. Retains pruning and graph criterion, replaces progress
printing with the actual class count. Reference counts 2, 20 and 250 come from the pinned unmodified source
compiled by MLton; the added driver only exposes f(n). Smoke counts two cumulative qualifying classes up to four vertices:
the two-vertex edge and four-cycle. A triangle violates the induced-subgraph
sparsity condition. The count is cumulative, not restricted to four vertices.
