# fft-sandmark provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/numerical-analysis/fft.ml and dune. Retain the directory MIT license,
Copyright 2015 Akinori ABE, and Dune's OCamlPro ocamlbench-repo adaptation credit.
There is no acquired input dataset: Main creates complex values (i,0).
OCaml 4.14.1 Complex sources and library notice are retained at
99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93 for the imported arithmetic semantics.

## Algorithm and variants

Preserve bit-reversed input copying, stage/butterfly order, the half-size twiddle
array, both source complex multiplications per butterfly, cached original a/b,
and the exact 3.14159265358979 pi literal. Complex.exp retains exp(re) times
cos/sin(im). The inverse routine scales and conjugates its input, then calls
forward FFT without a final conjugation. Thus it returns the conjugate of a
general inverse; the selected real ramp still returns the original real signal.
Preserve and test that source convention. This is distinct from the classic
SML FFT implementation and from nofib's FFT variants; retain the -sandmark name.

Complex records become SML real pairs and OCaml arrays become SML Array. This
allows host-specific real boxing/unboxing and should not be described as a
portable copy of OCaml's float-record layout. Positive bit shifts/masks become
bounded integer doubling/division/remainder. The selected power-of-two lengths
are at most 1,048,576, and all indices fit 31 bits. No evaluation-order change
moves a y array read past a butterfly write. No arbitrary precision is needed.

## Inputs, validation and adapters

Smoke 16 and normal 16,384 are deterministic reduced lengths; large preserves
the original default 1,048,576. Input remains the same i+0i ramp distribution.
Source Main initializes its array once at process startup. The portable driver
initializes a fresh array per run, including repeated in-process calls; document
this allocation difference when using that measurement mode. The unused Unix
times gather helper, unused Format import, commented GC settings and top-level
launcher move out of the portable kernel. The selected algorithm has no clock
or OS dependence and no replacement timing loop.

Check every forward coefficient against the closed-form ramp DFT before running
the inverse, then check every roundtrip component against (i,0). Checking the
forward transform before the inverse avoids retaining its array after the
inverse merely for validation. Validation adds an O(n) trigonometric pass and
one linear roundtrip pass to measured execution; no checksum substitutes for
checking actual values. Length, finite values and both complex components matter.

Absolute error budgets are 2e-14*(log2(n)+1)*n^2 for forward components and
4e-14*(log2(n)+1)*n for roundtrip components. They allow stage accumulation,
the source pi approximation and host math variation, with separate scaling for
frequency magnitudes and recovered data. They are conservative budgets for these
selected inputs, not a general proof about every FFT input or libm. Reflect k
to min(k,n-k) in the cotangent oracle to avoid cancellation near pi. Original
OCaml complete results at all profile lengths, independent quadratic DFTs on
small inputs and a genuinely complex input agree within these budgets. Retain
maximum errors and raw-output hashes. Large reference binaries are checked in
full before disposal; their digest and error summary remain recorded.

Negative checks reject identity transforms, coefficient/roundtrip perturbations,
wrong lengths and infinity, and test the acceptance boundary. Separate tests
cover bit reversal, input preservation and the general inverse convention.
Large SML execution is claimed only where explicitly recorded.

## References and runtime questions

Cooley and Tukey's [1965 FFT paper](https://www.cs.jhu.edu/~misha/ReadingSeminar/Papers/Cooley65.pdf)
anchors the algorithm family. The retained Sandmark and Complex sources define
this particular representation, arithmetic and inverse convention. Twiddle
creation, complex record representation, repeated products, stage locality,
copying, math-library calls and validation overhead are diagnostic hypotheses
until established by inspection or measurements. Standard comparisons use
identical SML; OCaml supplies a correctness reference.
