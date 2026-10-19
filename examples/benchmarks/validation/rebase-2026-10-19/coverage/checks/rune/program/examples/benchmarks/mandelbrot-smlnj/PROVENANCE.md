# mandelbrot-smlnj provenance

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mandelbrot`.
Source/individual headers, notice and adaptation patch are retained.

Retain corrected x_base+delta*j coordinates, initial z=c, ordinary
binary64 iteration, 1024 escape limit, actual iteration sum and default
2048-square grid. This is materially different from the old MLton/ML Kit
multiplication coordinate. Parameterize only dimension and recompute delta
for that dimension. Smoke/normal select 16/128; large preserves 2048.
Independent native upstream execution supplies fixtures; selected sums fit
32-bit signed arithmetic. Floating equality at escape boundaries is checked
against both MLton and SML/NJ before accepting the exact iteration count.

Diagnostic questions concern numerical representation, branching and loop
allocation. These are source-based hypotheses; see [the literature](../literature.md).
