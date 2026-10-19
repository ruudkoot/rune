# wang-lazy provenance

Selected numerical and list evaluation: lazy.

## Algorithm and workload

Apply the source's blocked elimination pipeline to a fixed tridiagonal numerical
problem, render every solution value, and compute an ASCII-sum/length checksum.
The input is n blocks of n+1 rows: boundary coefficients (0,3,2,5) and (2,3,0,5),
with (2,3,2,7) in between. Preserve forward elimination, reverse corrections,
coarse boundary equations and reconstruction. The middle input block is shared
across its n-2 uses. Every repetition constructs and solves a fresh problem.

## History, authorship, revision and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798,
`spectral/hartel/wang/Main.hs`, Makefile, its three 500-line stdout fixtures and
`spectral/hartel/Fast2haskell.hs`. Complete bytes are preserved under upstream/.
The collection name records the Hartel association; these files state no full
individual authorship or separate redistribution notice. No attribution or grant
is inferred from another component or from the short name Wang. This source is
a numerical workload. The established name is preserved with explicit lazy and
strict evaluation suffixes.

## Known variants and exact source behavior

Both variants retain the source equations, tuple fields, sharing, list order and
source operation grouping. The lazy variant memoizes numerical fields, matrix
rows and list spines; the strict variant evaluates these finite values eagerly.
Rendering remains a memoized character stream in both. Strict evaluation can
calculate fields that the lazy consumer leaves unused. Fast2haskell's miraseq is
identity on its second argument and does not force its first.

The source el31/el3 reconstruction expressions divide the diagonal by the
computed residual. Their empty-row cases divide the anchor RHS by its diagonal.
The source f_dist pairs the first boundary with the first matrix2 block, while
the leading output also uses that block. Preserve both choices exactly. Small
nonuniform inputs distinguish these source recurrences and pairing from other
reconstructions; the uniform all-ones workload alone cannot establish this
translation detail. Nearby example matrices and generic Fast library helpers
are unreachable from the benchmark entrypoint and are retained in source only.

## Portable SML97 translation and adaptations

Use the original four-field real tuples and persistent list structure, with
explicit memoized numerical cells for the lazy evaluation policy. Scalar factors
shared by several fields remain shared cells. The unused input/block fields are
not replaced with a precomputed solution. Source numeric operations and grouped
subtractions retain their order. The fixed generator is SML97; shell code only
handles compilation, processes and operating-system limits.

The selected arithmetic uses binary64 real values. Each computed scalar must be
finite and within absolute 1e-10 of one, substantially above the original trace's
maximum observed 5.38e-13 error while rejecting perturbations hidden by the
source formatter's 0.0005 threshold. The tighter check is additional validation;
the original threshold and ASCII rendering remain in the consumer. All selected
validated values render as 1. The decimal fallback is outside accepted profiles.
Complete reference comparisons also cover nonuniform values, independently of
this fixed-input bound.

Checksum accumulation uses strict SML integers. The source traverses all rendered
characters and computes sum(ord chars)+length, followed by /length. Per-invocation
checksums fit signed 31-bit Int: at n=150 the result is 2181430/45750. The driver
validates every generated checksum against the reviewed all-ones text calculation,
formats each repetition's result, consumes its emitted byte count, and reports
repetitions:checksum:bytes. This replaces 500 separate output writes with controlled
suite output while retaining numerical generation, character traversal and integer
formatting. The byte count is at most 7000 for the selected profiles. No sum of
500 large checksums is held in a narrow integer.

## Compiler/runtime questions

Investigate the effects of delayed real fields, shared blocks and elimination
factors, eager intermediate tuples, list traversal, allocation and collector
retention. These are source-derived hypotheses, separate from measured findings.
The original GHC program supplies correctness references. Measurements compare the identical SML program across
compilers. SML/NJ-specific diagnostic failures remain recorded with their default
settings; separate larger-nursery replays do not replace those failures or alter
the kernel. Causes remain unreduced unless a separate report establishes them.

## Inputs, correctness and references

| Profile | Block size n | Repetitions | One source checksum | Suite result |
|---|---:|---:|---|---|
| smoke | 25 | 1 | 66805/1375 | 1:66805/1375:11 |
| normal | 80 | 500 | 631490/13200 | 500:631490/13200:6500 |
| large | 150 | 500 | 2181430/45750 | 500:2181430/45750:7000 |

Normal and large retain the source NORM_OPTS/SLOW_OPTS and all 500 entrypoint
repetitions. Smoke preserves FAST_OPTS=25 and reduces only repetitions to one.
Default suite time/memory limits apply. Source dimensions, coefficient values,
block sharing, numeric type, work limit and all output adaptations are explicit.

The unmodified GHC program matches every byte of all three 500-line fixtures.
Full single-invocation observers record 650/6480/22650 values. An independent
mutable blocked solver agrees bit for bit with GHC on those 29780 values and
124 varied values from five nonuniform inputs. The SML semantic checker compares
all values with absolute+relative bounds, checks original checksums, repeat output,
source reconstruction formulas, unused RHS demand, memoized factors and deliberately
perturbed/nonfinite values. Default SML/NJ failures and separate replays are kept
as diagnostics. Whole-program normal and large Rune pilots retain all 500 solves.
Recorded coverage and the full repository check belong in validation.md and
results/m3-wang; these pilot facts alone do not close M3.

[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) provides suite
context. The pinned source supplies the algorithm and evaluation evidence here.
No unverified historical algorithm attribution or general solver claim is made.
