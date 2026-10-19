# count-graphs-mlkit provenance

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/count-graphs.sml`.
Original/headers, aggregate notice and adaptation patch are retained.

Henry Cejtin's original higher-order sparse graph folds. Preserve the
subset/permutation iteration, graph criterion, class pruning and mutable
cache implementation. Large retains 0..9 repeated ten times rather than
modern SML/NJ's 0..11 three times. f is cumulative up to its argument:
3*V-4-2*E=0 with induced-subgraph sparsity, not all graphs at exactly n.
Consume the complete count sequence; unmodified native SML/NJ/MLton
references and the two-vertex edge/four-cycle proof supply fixtures.

Diagnostic explanations remain source-based hypotheses, not measured
causes. See [the source-family literature](../literature.md).
