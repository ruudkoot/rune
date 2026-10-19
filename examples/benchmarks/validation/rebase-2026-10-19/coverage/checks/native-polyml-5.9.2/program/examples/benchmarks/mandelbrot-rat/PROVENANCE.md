# mandelbrot-rat provenance

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mandelbrot-rat`.
Source/individual headers, notice and adaptation patch are retained.

Retain the original rational numerator/denominator arithmetic, gcd, signed
shift-by-four truncation at 0x7FFFFFFF, corrected coordinates, 512 escape
limit and default 256-square image. Original intermediates require signed
63-bit arithmetic. Int63 emulates that range and Overflow in portable
IntInf, including counters, without depending on optional Int64. This
carrier changes allocation and is explicitly a translation decision.
Arithmetic right shift is IntInf.~>>, equivalent within the original range.
Fixtures are obtained from the original signed-63-bit SML/NJ computation.
Normal selects 32 square; large preserves 256. No exact-rational substitute
removes the original lossy truncation.

Diagnostic questions concern numerical representation, branching and loop
allocation. These are source-based hypotheses; see [the literature](../literature.md).
