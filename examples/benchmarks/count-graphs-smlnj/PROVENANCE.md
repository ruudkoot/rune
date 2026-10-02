# count-graphs-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/count-graphs`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

Henry Cejtin, modernized by John Reppy. Preserve higher-order
permutation/subset/graph folds, class pruning and mutable vertex caches.
Each f(maximum) counts classes at every size <=maximum satisfying
3*V-4-2*E=0 and its induced-subgraph sparsity condition; it is not a count
of all graphs of exactly the requested size. Preserve the original
0..11 sweep repeated three times in large; selected normal sweep ends at 6.
Return every sweep value instead of discard/progress output. Golden
values come from the unchanged upstream f on two native hosts.

All selected profiles retain meaningful source parameters; diagnostics graphs,higher-order,search
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).
