# kitmandelbrot provenance

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitmandelbrot.sml`.
Source/individual headers, notice and adaptation patch are retained.

Preserve the legacy multiplication coordinate x_base*(delta+j), initial
z=c, 1024 escape cap and pixel-count observation. The source increments
its sum by one rather than escape count; its old comment claiming 1084512
is stale for size 2048. Record both actual pixels and actual escape-step
sum so unused count computation cannot vanish from the validated workload.
This additional observation is documented measured work. Large preserves
three original 2048-square calls. Independent binary64 iteration supplies
fixtures for the old coordinate rule; modern SML/NJ uses addition instead.

Diagnostic questions concern numerical representation, branching and loop
allocation. These are source-based hypotheses; see [the literature](../literature.md).
