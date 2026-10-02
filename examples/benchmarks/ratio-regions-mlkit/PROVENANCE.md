# ratio-regions-mlkit provenance

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/ratio-regions.sml`.
Original/headers, aggregate notice and adaptation patch are retained.

Jeff Siskind's ratio-region reduction, tracing Cox/Rao/Zhong, Blicher,
Goldberg and Roy. Preserve the preflow-push algorithm, relabel/scheduling
heuristics, fixed synthetic central-square capacities and complete min-cut
array. Parameterize only grid side/repetitions, suppress diagnostics and
check every mask cell against the independently known central square.
Large keeps upstream side 64 and 1 calls; the four-call _tp
variant remains separately named. Ordinary integer operations stay in
range for selected dimensions; no flow/capacity representation changes.

Diagnostic explanations remain source-based hypotheses, not measured
causes. See [the source-family literature](../literature.md).
