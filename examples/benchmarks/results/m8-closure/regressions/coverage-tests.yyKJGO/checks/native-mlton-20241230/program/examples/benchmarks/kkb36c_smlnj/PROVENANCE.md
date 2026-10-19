# kkb36c_smlnj provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kkb36c_smlnj.sml`.
Individual headers and aggregate notice are retained with the pristine
source and patch.

Keep geometric Knuth-Bendix equations, ordering, typed equality where
present, recursive tuple argument shape, copied terms/rules and the
source's one-step tail-recursion batching. The upstream region functions are already no-ops and are retained.
Wrap the outer let/local declarations to expose one completion. Capture
the complete actual diagnostic/canonical-rule trace instead of console
printing; every byte influences the fixed Word32 summary. Normal preserves
three completions; smoke selects one, large ten. Golden traces are
reviewed native executions of this unchanged algorithm on MLton/SML/NJ,
with an independent bottom-up rule interpreter checking all seven open
axioms, 700 deterministic ground instances, and rejection of an omitted
rule (`tests/benchmarks/kb-oracle.py`).
No prerequisite compiler/runtime feature is added. Copying, lifetime and
argument shape are hypotheses; see [ML Kit/rewriting literature](../literature.md).

Exact launcher alias test/kkb36c_mlton.sml shares this kernel, dataset and
original repetition count; its pristine source is retained in upstream/.
