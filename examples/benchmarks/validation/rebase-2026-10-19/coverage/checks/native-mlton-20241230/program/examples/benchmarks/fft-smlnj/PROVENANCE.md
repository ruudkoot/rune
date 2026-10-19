# fft-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/fft`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

Copyright 2024 Fellowship of SML/NJ, alias fft64. Preserve the
analytical input, radix-two transform, and doubling sweep beginning at 16.
Large retains 21 levels, ending at 16777216 points. Replace optional
Real64Array/Real64 names by RealArray/Real guarded at radix 2/precision 53.
Return and validate the measured maximum residual against the analytical
ramp; absolute bound 1e-8*n follows the reviewed classic FFT checker.
Suppress progress printing. This bound is benchmark-specific and failed
residuals cannot become timings.

All selected profiles retain meaningful source parameters; diagnostics numerical,arrays,fft
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).
