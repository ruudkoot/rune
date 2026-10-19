# atom-lazy provenance

Finite-value evaluation: lazy.

## Algorithm and workload

Produce a prefix of the one-dimensional atom state stream using the original
force law and explicit-Euler position/velocity updates. Keep positions and
velocities as finite lists. The timestep is binary32 0.02, spring parameter [1],
initial position [1] and velocity [0]. The source displays only positions, with
a tab per component and newline per state.

## History, authorship, revision and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/atom/Main.hs,
Makefile and all stdout fixtures. The header attributes the kernel to Ron Legere
at Caltech Quantum Optics. It records a historical Classic Hugs/GHC discrepancy
and relates it to commoning identical recursive calls. That anecdote is source
history rather than a current timing result. Full source and attribution bytes
are preserved; no separate redistribution notice is stated in these files.

Retain the established atom name with lazy/strict suffixes. The repeated
self-call is intentionally part of this benchmark; a shared self-referential
stream or linear state iterator would be a different implementation. The
independent linear iterator used for reference generation is confined to checks.

## Source quirks, sharing and evaluation variants

Each experiment invocation creates a distinct child experiment with identical
parameters. Its force law and propagation share that child stream, while the
outer stream remains separate. The initial state head is shared across calls.
Small counted-law probes check triangular force demands: for n displayed states,
lazy mode demands (n-1)*(n-2)/2 force heads (zero below two), while strict mode
demands n*(n-1)/2. These checks detect accidental stream knotting.

The source Num-list multiplication computes the first product, then multiplies
the RIGHT tail by itself, ignoring the left tail. Preserve that behavior; the
one-dimensional profile does not exercise it, so separate two-dimensional source
oracles do. Addition preserves the longer tail and its source matching order.
The force stream matches State at spine construction, but propagation leaves
its force-vector argument undemanded until velocity needs it.

The lazy variant suspends finite vector spines/elements and state fields.
The strict variant evaluates those finite values eagerly, including terminal
velocities not displayed by the source. Infinite state/force streams remain
memoized in both modes. The lazy consumer never forces an unshown velocity
solely for validation. A source bad-force probe displays two positions without
demanding force, then fails on the third; the lazy port preserves that behavior.

## Portable arithmetic, drivers and adaptations

Use the existing finite-normal binary32 helper shared with Mandel2. Values are
stored exactly in binary64 and rounded to 24 significand bits after each source
operation, ties to even. No optional Real32 structure or runtime feature is
required. Independent original-profile checks establish that every selected
operand/result is zero or normal; nonzero frexp exponents stay in [-18,2].
Products of binary32 operands need at most 48 significant bits; observed addend
exponent gaps are at most 19, so sums need at most 43. The binary64 intermediate
therefore represents these selected operations exactly before binary32 rounding.
The helper does not claim general subnormal/overflow/transcendental support.

Word32 encodes and checks every displayed position bit for bit. Masks, exponents,
indices and formatting counters have explicit bounded widths; signed zeros are
distinguished by the encoder. The initial timestep has bits 3CA3D70A. Each driver
invocation creates a fresh experiment instead of retaining the source top-level
test CAF across repeated suite invocations. Internal child-stream sharing is
retained. Profile arguments and the reviewed position file are read once.

Numeric formatting uses SML GEN9 instead of Haskell's shortest Float renderer.
Every numeric character is inspected, a binary32 roundtrip is checked, and tab/
newline lengths are consumed. Renderer-dependent text lengths are bounded rather
than exposed as cross-compiler expected output. Controlled output reports
position-count:rolling-bit-checkword, using explicitly modular Word32 xor/multiply
(seed 811C9DC5, multiplier 01000193). Every position is independently checked
against its fixture before contributing; this checkword does not replace checking.

## Compiler/runtime diagnostic questions

Investigate unshared recursive calls, within-invocation sharing, finite eager/
lazy vectors, unused velocities, closures, list temporaries, GC and whole-program
specialization. Emulated binary32 rounding and format validation are substantial
parts of this SML workload. Timing comparisons use identical SML across compilers;
GHC supplies correctness references. The source's historical compiler story does
not establish a performance explanation for current configurations.

## Inputs, correctness and references

| Profile | Displayed states | Input origin |
|---|---:|---|
| smoke | 100 | bounded prefix of the original FAST workload |
| normal | 2500 | unchanged NORM_OPTS |
| large | 4000 | unchanged SLOW_OPTS |

All three original 1000/2500/4000-state text fixtures remain in provenance.
Smoke uses 100 states to cover negative positions while keeping routine checks
bounded; normal/large keep the original parameters. Default limits apply.
Upstream text/bit observers agree with an independent linear binary32 Euler model
on all 4000 positions and velocities. Observers force velocities for auxiliary
checking; the primary lazy benchmark preserves the position-only demand.

SML probes check exact position/state bits, stream demand/triangular structure,
source vector quirks, sharing, ties to even, signed zero, finite-helper domain,
format roundtrip and wrong/short/extra references. Whole normal Rune O2 pilots
validate both policies at 2500 positions. Other coverage is recorded in validation.md.

[The pinned program](https://gitlab.haskell.org/ghc/nofib/-/blob/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/atom/Main.hs)
provides the algorithm, attribution and historical explanation.
[Partain](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies nofib context.
[The SML Real interface](https://smlfamily.github.io/Basis/real.html) specifies the
rounding/conversion operations used by the helper. Source analysis, finite-input
bit checks and future performance explanations have separate evidence scopes.
