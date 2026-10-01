# fft

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/fft.sml`.

Retains the in-place FFT, bit reversal, complex arrays and analytical
input whose transform should be the real ramp 0..n-1 with zero imaginary
component. The original error computation is now returned instead of
discarded. Every run checks maximum residual <= n*1e-8; the nonnegative
check also rejects NaN. Large is the largest original transform. Numeric
validation is separate from exact result formatting.
Original source, notice and separate adaptation patch are retained.
