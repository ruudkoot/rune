# durand-kerner-aberth provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/numerical-analysis/durand_kerner_aberth.ml and dune. Retain the
MIT notice, Copyright 2015 Akinori ABE, embedded coefficient table and OCamlPro
adaptation credit. Complex helper semantics/notices are retained from OCaml
4.14.1, revision 99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93. No external dataset
is acquired; the 98 coefficients are the upstream program's constants.

## Algorithm and variants

Use the source's Durand-Kerner simultaneous root updates and Aberth-style
circle initialization: radius 1,000, coefficient-derived center, rotated angles
and the exact pi literal 3.14159265358979. Each new root vector reads the whole
old vector. Preserve Horner evaluation, sequential reference accumulation of
root-difference products, leading coefficient, stable ratio-based complex
division and reverse-index convergence scan. Do not substitute a full
Ehrlich-Aberth iteration or update roots in place. Retain the established
upstream compound name while explaining which method the source implements.

Stopping uses squared complex displacement <1e-6 for every root. That is not
a 1e-6 absolute-root accuracy claim. It is deterministic; unchanged selected
inputs converge without a replacement work bound. Ordinary profile time/memory
limits detect failures. OCaml float records become real pairs, arrays remain
arrays, and for loops become portable tail loops. Scalar mutable accumulators
remain refs. No arbitrary precision is used in the measured kernel.

## Inputs and validation

Smoke 10%, normal 50%, large 100% select the exact leading coefficient prefix
with floor(98*percent/100), giving degrees 8/48/97. Large preserves the source
default. All profiles retain Main's ten root searches. Read-only coefficients
load once on the first run through a memoized SML delay; repeated calls reuse
them and select a new prefix. Source globals initialize before Main, so input
loading/prefix creation and first-run warmup costs are explicit adaptations.

Compare every computed root to a distinct high-precision reference root,
allowing permutations. Absolute complex-distance budgets are 1e-8/1e-6/1e-4
for smoke/normal/large. The reference loader requires separation >4*budget;
finite checks, counts and one-to-one matching reject missing/duplicate roots.
These budgets cover the source's approximate termination on selected inputs,
not arbitrary polynomials. Fixtures are read each run, and matching costs are
part of execution. The final line reports percent:total-roots:checked.

All original ten-search profiles complete. Independent 80-digit Newton
refinement of each original root and reconstruction of every monic coefficient
certify distinct complete root sets. Original maximum root errors are about
3.14e-11,1.98e-8,1.68e-6, and minimum separations .712/.119/.0165, respectively.
Complete source outputs, refined roots and reconstruction errors are retained.
Large SML execution is claimed only where recorded separately.

Semantic checks cover complex division scaling, Horner evaluation, circle
initialization, strict squared stopping, known linear/quadratic roots, vector
lengths, permutation acceptance and duplicate/missing/perturbed/nonfinite roots.

## References and runtime questions

Aberth's [1973 paper](https://www.ams.org/mcom/1973-27-122/S0025-5718-1973-0329236-7/S0025-5718-1973-0329236-7.pdf)
provides the simultaneous-root-method context and references Durand and Kerner.
The retained code determines the actual update and initialization here. Pair
boxing, polymorphic accumulator refs, allocation, Horner specialization,
math-library calls, root order and convergence variation are diagnostic
questions until supported by compiler inspection or measurements. Standard
comparisons use identical SML; OCaml supplies the source reference.
