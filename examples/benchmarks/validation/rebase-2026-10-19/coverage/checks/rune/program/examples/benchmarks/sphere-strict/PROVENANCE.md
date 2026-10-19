# sphere-strict provenance

Numeric policy: strict.

### Algorithm and workload

Trace a square image of ten source spheres with point lights, shadows, diffuse
and specular shading and recursive reflection. Retain vector/scalar operation
order, the source intersection-list construction, right-associated vector sums,
fold-right nearest-hit selection and contribution-based recursion cutoff.

### History, authorship and variants

David J. King, July 16, 1998, Haskell port of the Impala Id sphere tracer.
The retained October 1 correspondence explicitly supplies a sequential program
for the SCOFPIG challenge. No Impala runtime or parallel facility is needed.
Pinned nofib revision b7391df4540ac8b11b35e1b2e2c15819b5171798,
spectral/sphere. The individual source/correspondence states no separate
redistribution grant; retain its complete attribution without inferring another
benchmark's license or inventing the earlier Id author's identity.

This program differs from the other ray tracers in scene, camera, surfaces,
intersection selection and recursive shading. Keep its established sphere name.
Lazy and strict numeric payload policies have separate names. The original
source is retained under sphere-lazy/upstream; the scene and lights are generated
constants, with no external dataset or image-file dependency.

### Translation and source behavior

All kernels, drivers, scene generation and checks use SML97. Memoized control
streams and vector nodes preserve demand and sharing; numeric coordinate
payloads are memoized in lazy and eager in strict. The finite source scene,
surface and light constant lists use immutable SML lists. Fresh camera/image
computation occurs on every repetition; no rendered image is cached.

Both policies retain lazy branch selection and recursive ray controls. Unused
numeric coordinates can remain unforced in lazy. Source integer indices fit
portable int. Floating operations use Double-compatible real arithmetic.
The source signed machine-Int hash is made explicit modulo 2^64 with Word64;
selected quantized colors fit portable signed int. Round color*255 to nearest
with ties to even. Preserve negative/out-of-range colors rather than clamp them.

Preserve historical quirks: the zero-vector cutoff tests signed components
against epsilon instead of absolute values; shadow intersection is not bounded
by light distance; nearest-hit folding has the source tie order; transmitted
rays return a false TIR flag even though refractray computes one.
The selected scene has zero transmission, so transmission behavior is a
source-inspection observation, separate from measured standard profiles.

### Inputs and result checks

| Profile | Repetitions | Square image size |
|---|---:|---:|
| Smoke | 1 | 30 |
| Normal | 100 | 100 |
| Large | 100 | 250 |

Smoke reduces source FAST's 100 repetitions to one. Normal/large retain the
source dimensions and counts. Every pixel checks its coordinates, all three
raw color channels and exact quantized colors against reviewed reference rows.
Use absolute 1e-9 plus relative 1e-9 for each finite raw channel. These are
source-agreement bounds, not a formal proof for all host math libraries.
Quantized colors remain exact, including ties-to-even controls.

A streaming forward weighted polynomial reproduces the source right-fold hash
modulo 2^64 while validating the complete image. Report repetitions:checked-pixels
and the final hexadecimal Word64 hash instead of repeated signed decimal hashes.
No early stopping, random seed or source algorithm change is introduced.

Unmodified GHC reproduces every 100-line profile fixture. An export-only observer
records all 73400 pixels across the three image sizes; an independent eager
tracer agrees on every quantized channel, with maximum raw difference below
5.7e-12. The independent model computes camera normalization and closest-hit
selection separately rather than duplicate the stream implementation.

The 69-check target covers original vector/shader fixtures, complete smoke
images, intersections/tangency, surface defaults, TIR, source cutoff/tie/sum
quirks, numeric perturbations, quantization, invalid reference data and sharing.
All six native hosts and Rune pass private semantic checks. Both full normal
SML profiles pass guarded final-source calibration. Canonical matrices/counts
are recorded with the import wave. Full SML large repetition runs remain
unrecorded, separately from their complete reference pixels and source fixtures.

### Literature and diagnostic questions

The retained source and correspondence establish algorithm and translation
history. The refractray comment cites Foley and van Dam, page 757; retain that
limited source attribution without inferring an edition or a reviewed passage.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) provides suite
context. Investigate coordinate demand, recursive-ray allocation, scene-list
traversal, nearest-hit sharing, shading math and the pixel/hash consumer.
These are source-based hypotheses until supported by measurements.

[Canonical host findings](../validation/sphere-host-results.md) retain the
lazy-normal legacy 64-bit SML/NJ mismatch and its separate controls.
