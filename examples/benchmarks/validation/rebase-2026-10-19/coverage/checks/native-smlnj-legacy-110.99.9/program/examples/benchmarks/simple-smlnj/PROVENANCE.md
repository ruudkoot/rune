# simple-smlnj provenance

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/simple`.
Original modules/headers, aggregate notice and adaptation patch are retained.

Preserve one hydrodynamic step, initial-state distribution, boundary handling
and every final velocity/position/pressure/density/energy array. This modern SML/NJ variant uses its original flat custom Array2 and default
560 grid. The expectedDelta/C functor constants are output checks, not
inputs to the simulation; the full-state checker replaces them.
Move the simulation declarations into a parameterized compute scope; retain
original array representations. Suppress progress and validate every actual
state element against native reference output, abs 1e-8 plus rel 1e-7.
Normal selects a practical grid; large preserves the original dimension
and 1 calls. Input generation and full observation are measured work.
Representation/lifetimes/numerical cost are source hypotheses, not measured
causes; see [the classic/ML Kit literature](../literature.md).
