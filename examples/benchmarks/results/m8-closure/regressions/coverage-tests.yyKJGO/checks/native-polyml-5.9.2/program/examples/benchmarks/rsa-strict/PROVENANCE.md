# rsa-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/rsa`.

Complete pinned sources, build parameters, input/output fixtures and SHA256
identities are retained. Individual licence notices remain unspecified where
not present in source. Kernels and shared translation support are SML97.
Source inspection explains the following behavior; performance sensitivities
remain hypotheses until measured. Large SML execution is not universally claimed.

## Algorithm, history and variants

The source's individual author/licence is unspecified. Fixed large modulus and
exponent from Main.hs remain exact IntInf values. Preserve base 128 block coding,
block size(decimal digit length*47 div100), recursive exponent halving for even
powers and decrement/product for odd powers, modulus placement, decimal lines
and trailing newlines. Unused decrypt/key-generation helpers remain in the
original source. No built-in modular-power routine replaces this recurrence.

## Translation and runtime questions

Both variants share one algorithm. Lazy base-code arithmetic and ciphertext
chunk heads/spines are memoized; strict evaluates those finite encodings eagerly.
The selected entire ciphertext is needed, but intermediate retention/allocation
and input-encoding demand differ. Exponent0 returns1 without forcing the lazy
base, including modulus 1, matching the source's exact stopping rule. All RSA
arithmetic is arbitrary precision; block indices/counts fit 31 bits. Fixed inputs
are ASCII, so SML byte/character values agree with original Haskell input.
SML materializes input/block/output strings instead of character lists.

Repeated BinIO input acquisition is the portable observable substitute for
nofib's NOINLINE IO salt. This adds file I/O and copying per repetition; it is
explicitly included rather than adding a compiler opacity feature. A preloaded
ciphertext fixture validates every line before the wrapping64-bit source hash;
an IntInf sum consumes all repetitions. Standard timing comparisons use these
identical SML sources; Haskell originals are correctness references.

## Inputs, validation and references

Smoke takes the first 64 bytes of original FAST 411 and one repetition. The full
411-byte smoke input timed out after 30seconds on the unoptimized stack engine;
that rejected attempt remains recorded. Normal uses full FAST 411 with 10
repetitions; large uses original NORM 3169 bytes with 150 repetitions. Original
FAST 100/SLOW 250 and SLOW 10052-byte input remain retained. Every ciphertext block
agrees with GHC and independent Python modular pow, including the exact source
block-width rule. Semantic tests cover base 128 encoding, exponent parity,
empty input, block width and unneeded-base demand. The combined paired test
shares the recorded ML Kit StatObject compiler-crash limitation; passing
configurations and standalone runs remain distinguished. Big-integer division,
encoding thunks, decimal conversion and retention are source hypotheses until
measured. References: retained implementation and nofib literature survey.
