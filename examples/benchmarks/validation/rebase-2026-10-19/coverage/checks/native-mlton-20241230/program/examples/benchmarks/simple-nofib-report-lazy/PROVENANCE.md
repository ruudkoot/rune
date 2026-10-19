# simple-nofib-report-lazy provenance

### Algorithm and workload

Advance the original two-dimensional SIMPLE hydrodynamics/heat-conduction
state using immutable boxed arrays: velocity and position, area/volume and
density, artificial viscosity, temperature, pressure/energy, two directional
heat sweeps, energy error and adaptive time step. Retain polynomial table
searches, finite-difference Newton updates and every source arithmetic order.

The totals consumer forces thirteen final scalar sums without printing the
original state. The report consumer formats every coordinate/value in eleven
arrays plus time step and error, constructs the complete report and writes it
to standard output. Both consumers force the thirteen totals of each
intermediate state before advancing. They share one numerical implementation
but remain separate workloads because final traversal, formatting and I/O
differ materially.

### History, authorship, aliases and source variants

[nofib spectral/simple](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/simple)
is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. The Id source credits Kattamuri Ekanadham and carries
1989 correspondence/edit history. Its Haskell translation is described as an
Id-to-pH translator with hand-added types and strictness annotations; do not
invent a named translator from that description. Historical MAIL documents
RPaul Johnson's Haskell/pH correspondence, Andy Shaw's C submission, and a
Fortran version supplied by Olaf Lubeck. The C file explicitly credits both
Andy Shaw and Kofi Fynn. Supplying the Fortran is not proof of sole authorship.

Preserve Main.hs, Makefile, MAIL, simple.c and simple.f in full. No separate
permission notice is stated for these individual files. The repository-level
nofib notices remain recorded in the pinned inventory. Embedded numeric
constants and geometry are the input; no external historical dataset is
silently substituted.

Makefile explicitly selects SRCS = Main.hs to exclude the C comparator.
The Fortran source is likewise outside that build. Both ancillary comparators
are preserved and inventoried with this concrete build-scope exclusion,
rather than claimed as additional passing nofib executables. The C pi
constant differs and Fortran declares single-precision REAL; neither is an
exact binary64 oracle for this Haskell program.

The classic unsuffixed simple and simple-smlnj imports retain their mutable
SML implementations and original profiles. This port uses the -nofib collision
suffix. Memoized and strict finite-array policies receive -lazy and -strict;
the reporting consumer adds -report before the policy suffix. Similar ancestry
does not establish identical representations, evaluation or input profiles.

### Translation, numeric semantics and demand

Keep the original boxed, immutable arrays with inclusive tuple-index bounds,
row-major enumeration, shared pair/triple results and memoized real cells.
Keep the original nbc boundary-code array and its undefined interior cells,
the four-entry pbb/pb tables and the qb alias of pb. One-dimensional constant
tables use vectors with explicit one-based source index translation. A private
association builder fills the immutable nbc array, sharing its missing-element
cell and literal values. Strict construction materializes supplied entries
while leaving omitted source cells undefined. No boundary lookup is replaced
by an equivalent conditional computation.

Paired/triple array results use a shared memoized tuple table in this portable
encoding. Projection closures can retain that table until they are consumed;
this additional support storage and its lifetime are explicit representation
costs, not a claim of identical GHC object layout or retention.

Recursive boundary arrays and forward/backward heat recurrences install their
shared stores before optional strict materialization. Lazy projections do not
force unused tuple fields. A strict policy materializes finite array cells
when its array root is demanded; memoized state/control roots remain shared.

Preserve memoized scalar-list elements and the source left folds for array
totals, polynomial sums, energy/error reductions and time-step extrema.
Lazy accumulators remain delayed until their result is demanded; strict
variants force each accumulator before continuing. Array elements are
enumerated through the boxed vector in source row-major order. Do not fuse
these source producer/fold pipelines by hand.

Retain the fixed thirteen-tuple of delayed totals behind a memoized root.
Intermediate loop checks force it before advancing; the reporting consumer
leaves the final totals root unused. Conversion to a list is a separate
correctness-observation adapter. The first revised-energy term is shared
across Newton evaluations, as in the original binding.

The source strictArray evaluates only the first constructor of map evalValue
(elems array). It does not traverse and force every element, despite its
comment. The lazy policy follows actual demand; the strict policy is a
separately named finite-materialization experiment. Do not repair the source
helper according to its name.

Preserve the source's positive-residual-only Newton stopping test and its
reuse of the previous residual argument. Preserve the energy-error boundary
work calculation that reads pressure into its u1/u2 variables and position z
into w1/w2. These are source behaviors, not corrections to a physical model.
Retain exact operation grouping, table coefficients, boundary classifications,
reflection directions, sweep dependencies and traversal/reduction order.
The upstream source contains a stale size-10 comment; its actual grid_max is
100. Normal and large retain it; the smoke-only grid reduction is explicit.

Use binary64 real arithmetic, including source powers, sqrt, trigonometric
initialization and fractional power. Do not round to binary32 or reuse the
classic imperative implementation. Integer coordinates, counters and cell
counts fit signed 31-bit integers. Reference hexadecimal bits decode using
portable IntInf arithmetic and Real.fromManExp, avoiding optional packing
structures. Explicit tuple patterns and numeric types resolve Standard ML
record overloading/value restrictions without host-specific kernels.

The original positive consumer emits nothing. Add a checked compact summary
for the common runner. The report consumer retains the complete headings,
bounds, coordinates, order, eleven arrays, scalars and done marker. Map its
Haskell shortest floating printer to SML97 Real.fmt GEN17, normalize sign and
exponent spelling, and verify every rendered number parses back within the
same documented error bound. Decimal spellings can differ by host; numerical
values and structure supply the oracle, not one host's formatted text.
The full report still reaches controlled standard output before the common
RESULT/PASS/SUMMARY protocol. Formatting and I/O remain part of this workload.

### Profiles, input generation and result validation

| Profile | Grid maximum | Steps |
|---|---:|---:|
| Smoke | 8 | 1 |
| Normal | 100 | 20 |
| Large | 100 | 100 |

All three preserve the original FAST/NORM/SLOW step counts. Smoke reduces
the compile-time grid maximum from 100 to 8 for bounded correctness checks;
normal and large retain the actual upstream grid maximum 100. A thin
profile-specific SML driver selects that constant; the numerical kernel and
data representation are identical. The full-grid source FAST observations
and initial attempts are retained separately. The driver accepts
bounded step counts 0..100 and requires an explicit reviewed reference.
Inputs preserve source constants, polar geometry and boundary distributions.
Normal and large use the actual grid of 100. Smoke and the bounded semantic
target use a separately recorded source-constant configuration with grid 8.
A complete one-step report has 708 cells at grid 8 and 110004 at grid 100.

Totals require thirteen finite results. Reports require the exact eleven
names, inclusive bounds, row-major coordinates, number of cells and finite
scalar values, then validate each formatted numeric token. Per-cell and scalar checks retain abs(x-e) <= a + r*abs(e), where
a=1e-12 and r=1e-11. Array sums need a conditioning-aware bound: let n
be the number of cells, S an upward-rounded sum of reference magnitudes,
u=2^-53, gamma=n*u/(1-n*u), and B=n*a+r*S. Require aggregate error at most
(1+gamma)*B+2*gamma*S, with outward rounding padding. This follows from
componentwise compatibility and the recursive-summation error model;
it does not prove physical-model accuracy. Time step and energy error
retain the original scalar bound. Exact rational review checks every
reference scale/bound and deliberate out-of-bound perturbations.

The recursive-summation model is reviewed in Higham,
[The Accuracy of Floating Point Summation](https://nhigham.com/wp-content/uploads/2023/10/high93s.pdf),
1993, section 2, especially the bound in equation 2.6. The combined
componentwise/aggregate bound here is a separately derived application.
No summation algorithm, ordering, expected value or per-cell tolerance changes.
Deliberately perturbed near-zero and large values, NaN, infinity, malformed
bits, bad counts/shapes/steps and incorrect references must be rejected.
Do not widen this bound to hide a host failure.

Unmodified original totals-mode executions at 1/20/100 steps return no stdout
as required. Read-only observers capture every array cell and all thirteen
totals at 0/1/2/5/20/100 steps. Both initial SML policies agree bit for bit on
every captured full-grid state, including the complete 100-step large state;
this is observed agreement, not a requirement to substitute approximate
golden aggregates. Original reporting-mode outputs at 1/20/100 steps decode
to the same 110004 final array cells; complete source reports are preserved.
The zero-step state has 800 additional velocity boundary cells.

### Compiler/runtime questions and evidence limits

Investigate immutable-array construction, thunk memoization, shared tuple
projections, recursive array lifetimes, direction-dependent sweeps, reduction
chains, floating-point primitives and complete report allocation/I/O.
These are hypotheses from source analysis. Same-source SML engines/hosts are
the performance comparison; Haskell is a correctness reference. Source and
adapter differences prohibit attributing cross-language times solely to
compiler quality.

Full-grid state observations, bounded semantic checks, primary profiles,
guarded counts, serial timing-adapter diagnostics and repository acceptance
are recorded separately. A passing initial private pilot does not establish
that a later host/profile passed. Retain compile errors, incorrect numerical
results and resource failures explicitly; no failed case contributes timings.

### Literature and review scope

Arvind and Kattamuri Ekanadham, [Future scientific programming on parallel
machines](https://research.ibm.com/publications/future-scientific-programming-on-parallel-machines),
Journal of Parallel and Distributed Computing (1988), supplies background.
The reviewed IBM abstract describes composing a SIMPLE excerpt from Id
Nouveau functions and discusses transformations such as inlining. That is
paper-supported context rather than a measured explanation for this port.
Only the abstract/metadata was reviewed here; do not imply a full paper review.

The pinned program references CSG 273 and contains specific equation/edit
history. Its MAIL warns about the historical physical correctness question
and small-grid long-run NaNs. Validation establishes agreement with this
specific Haskell program, not validation of the physical model. No parallel
runtime feature is introduced. Upstream mutable C/Fortran comparisons and the
classic SML version need separate numeric/evaluation review before any claim
of equivalent costs or exact results.
