from pathlib import Path
suite=Path('examples/benchmarks')
body="""### Algorithm and workload

Run the source Cg iterative linear-system solver over generated sparse matrices
whose entries are dense four-by-four Float blocks. Retain block-diagonal scaling,
the pseudofactor preconditioner, dense pivoted inversion, forward/back substitution
and the x/r/p/q state updates. Main's historical header calls the method Bi-CGSTAB;
this port follows the actual Cg equations rather than substitute a textbook solver.

### History, authorship, revision and variants

Brian D. Moe wrote the solver/support code in summer 1990; Kamini Shenoi modified
it in summer 1991. Ian R. McLelland and Cordelia V. Hall converted it to Haskell
in November 1992. Input.lhs credits Roger L. Wainwright's data representation and
Dan Vasicek's reader code. Original individual credit/notice headers are retained;
no separate dataset redistribution grant is inferred from another workload.

Pinned nofib revision b7391df4540ac8b11b35e1b2e2c15819b5171798,
real/linear and gc/linear. Both complete original module trees remain under
linear-lazy/upstream-real and upstream-gc, including the common NofibUtils helper
used by real. Generated hard_data needs no external dataset.

The application variant caps the state sequence at ten and hashes the complete
formatted result 200 times. The GC variant caps it at fifty and prints the result
once. Preserve both consumers and stopping conditions, sharing one reviewed
numerical implementation. Names linear-lazy/strict select the application;
linear-nofib-gc-lazy/strict disambiguate the GC source category. Each retains its
upstream linear alias.

### Translation, data structures and evaluation

All kernels, generation, checks and formatting use SML97. Dense blocks/vectors
and sparse row/entry lists retain the original list structures through memoized
streams. Scalar Float calculations round to binary32 after every operation;
representation uses the common binary64 real type with explicit normal/subnormal,
nearest-even and overflow handling. Selected integer indices fit signed 31-bit int.
No arbitrary-precision replacement of source arithmetic is introduced.

Preserve the scale/preconditioner function parameters, shared partial conditioner
application, higher-order maps/folds and exact accumulation order. A recorded
original GHC interface gives precond arity three. The translation computes each
pseudofactor at that source full-call boundary and adds no cross-call factor cache.

The factor matrix is tied recursively through memoized block/list controls.
Forward substitution retains function-based y calls and its shared sumparts;
back substitution retains the source shared ps lookup and termss. Preserve these
different sharing patterns rather than memoize every recursive function.
Final p/q fields remain outside the displayed metric demand. Numeric payloads
are memoized in lazy and eager in strict; structural controls remain memoized in
both policies, allowing finite strict evaluation to change allocation/forcing.

Keep source diagonal handling, pivot ties, row/column swaps, indexing checks,
empty/singleton block operations, tuple-variable shadowing and block-multiplication
association. The mixed-size well branch is ported and checked against an original
synthetic case, even though the timed generated workload has zero wells.

### Inputs, known modes and profiles

| Source family | Profile | Repetitions | Grid side | State cap |
|---|---|---:|---:|---:|
| Application | Smoke | 1 | 2 | 10 |
| Application | Normal | 200 | 4 | 10 |
| Application | Large | 200 | 7 | 10 |
| GC | Smoke | 1 | 2 | 50 |
| GC | Normal | 1 | 14 | 50 |
| GC | Large | 1 | 16 | 50 |

The block grid has side^2 rows; every block is four-by-four.
Application normal/large and GC normal retain source parameters. Smoke reduces
work for routine correctness; GC large is an explicit scaling selection.
Keep the stopping predicate sqrt(norm r) < Float(0.0000004), inclusive takeuntil
behavior, initial state and source cap. The fifty-state normal GC result reaches
its cap with nonzero residual; this is the reviewed source result.

Source test-function options also discuss easy_data, no scaling/preconditioning
and a reservoir gcomp_data mode. The published mains select bilu/hard_data/conv2.
Generic scale/preconditioner callbacks remain, with demand controls in tests.
The reservoir readers currently use literal abc strings and their Data/gcomp.mat*
files are absent. Supplementary inventory entries defer those inactive data
modes until deterministic licensed fixtures and reviewed readers are available.
No prerequisite compiler/runtime feature is added.

### Result consumers and correctness

Validate every demanded iteration index, norm(x-soln) and norm(r) against an
original metric table. Results must match the reviewed binary32 values exactly;
there is no additional numerical error allowance. GEN9 formatting must roundtrip
to the same binary32 value and retains source column widths, headers and START/END
framing. The stable report counts repetitions, checked states and formatted
characters rather than expose platform-dependent shortest decimal hashes.

Application mode still performs the source forward modular Word64 hash over
the adapted text, with an independent reverse polynomial check. GC mode consumes
the formatted text without adding that hash workload. The adapter buffers bounded
formatted rows for validation instead of repetitive stdout. These consumer and
decimal-spelling adaptations are recorded separately from numerical algorithms.

Unmodified GHC matches every supplied application fixture and the GC normal
fixture. Export-only observers expose demanded metrics, inverse/scaled blocks,
preconditioned vectors and a mixed-size well case. Small and full normal Rune
pilots agree under both evaluation policies. Final canonical source checks follow
the explicit callback signature needed for portable SML record resolution.

The 69-check target compares original dense/scaled/preconditioned values and
small metric sequences, verifies a mixed well branch, checks source hash/framing,
roundtrip formatting and incorrect-row rejection, and exercises binary32 ties,
subnormals and overflow. It also proves unused scale/conditioner callbacks remain
delayed. Native host findings and complete canonical matrices are recorded as
they finish. Full SML large repetition checks remain unrecorded unless explicitly
listed in the validation archive.

### Literature and diagnostic coverage

The retained source establishes this particular solver and preconditioner.
[Saad, Iterative Methods for Sparse Linear Systems](https://www-users.cse.umn.edu/~saad/IterMethBook_2ndEd.pdf)
provides general iterative-method/preconditioning context.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies suite
context. Do not identify a general accuracy or convergence theorem from the
source's historical method label.

Investigate callback specialization, sparse/dense list traversal, Float rounding,
factor recomputation, recursive sharing, live state lifetimes and adapted text/hash
consumers. These are source-based hypotheses; original metric agreement and
measured compiler configurations are separate findings.
"""
f=suite/'README.md';text=f.read_text();pos=text.index('\n## ',text.index('| [kronecker]'))
table=''
for kind in ['real','gc']:
 for mode in ['lazy','strict']:
  name=('linear'if kind=='real'else'linear-nofib-gc')+'-'+mode
  table+=f'| [{name}](#{name}) | [nofib {kind} linear solver](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/{kind}/linear) | Run the source binary32 block solver with {mode} numeric payloads and the {kind} iteration cap and consumer. |\n'
  (suite/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body)
text=text[:pos].rstrip()+'\n'+table+text[pos:]
for kind in ['real','gc']:
 for mode in ['lazy','strict']:
  name=('linear'if kind=='real'else'linear-nofib-gc')+'-'+mode;text+='\n## '+name+'\n\n'+body
f.write_text(text)
