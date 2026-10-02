# kitsimple provenance

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitsimple.sml`.
Original modules/headers, aggregate notice and adaptation patch are retained.

Preserve one hydrodynamic step, initial-state distribution, boundary handling
and every final velocity/position/pressure/density/energy array. This ML Kit variant uses lists of references as arrays; replacing them by
flat arrays would change its lifetime/traversal workload and is not done.
Move the simulation declarations into a parameterized compute scope; retain
original array representations. Suppress progress and validate every actual
state element against native reference output, abs 1e-8 plus rel 1e-7.
Normal selects a practical grid; large preserves the original dimension
and 1 calls. Input generation and full observation are measured work.
Representation/lifetimes/numerical cost are source hypotheses, not measured
causes; see [the classic/ML Kit literature](../literature.md).
