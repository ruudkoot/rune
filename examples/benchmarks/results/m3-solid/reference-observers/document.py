from pathlib import Path
import csv
s=Path('examples/benchmarks');revision=next(r['revision']for r in csv.DictReader((s/'upstreams.tsv').open(),delimiter='\t')if r['source']=='nofib')
body=f"""### Algorithm and workload

Approximate the area of a fixed two-dimensional constructive solid using
adaptive four-way spatial subdivision. Preserve postfix CSG parsing,
primitive bounding-circle pruning, source Boolean simplification order,
the classification tables, midpoint approximation, terminal stopping and
right-associated area accumulation. The selected embedded scene is the union
of 300 circles; do not replace the kernel with uniform-grid sampling.

### History, names, source defect and notices

[nofib Hartel solid](https://gitlab.haskell.org/ghc/nofib/-/tree/{revision}/spectral/hartel/solid)
is pinned at {revision}. The generated module states no individual author or
separate program/dataset notice. Preserve the complete module, original
Makefile/fixtures and parent Fast2haskell shim without assigning helper credits
to the program or embedded numeric data.

The original classification adapter contains a concrete indexing defect:
the list adapter is zero-based, but callers supply one-based vector indices.
For example union(OUT,OUT) returns UNKNOWN, and the normal depth-nine scene
overcounts 65 finest-grid cells. Original FAST/NORM/SLOW outputs still match
their supplied fixtures; those fixtures retain the defect.

The runnable port applies the reviewed one-line correction in the indexing
adapter, preserving every table entry and operation. A corrected Haskell
reference and an independent geometric oracle agree. The unrepaired baseline
has an explicit correctness deferral in the variant inventory, with its
original fixtures and counterexamples retained. It is not a passing workload.
The -lazy/-strict names distinguish finite numeric/data materialization.

The line primitive's unusual point-expression grouping is retained from
source; selected profiles contain only circles. Source-observation controls
record that unused branch without claiming general geometric validation
of arbitrary line scenes.

### Translation, demand and numeric decisions

Use policy-controlled finite point/primitive/cell fields and child-list data.
Both policies retain memoized CSG and subdivision control, preserving pruning
before expansion. Strict variants materialize finite fields; neither eagerly
builds an unbounded spatial tree. Midpoint coordinates and shared child bounds
retain their source sharing.

Preserve the order of full/empty checks. Union with a full left child skips
the right child; intersection checks the right-full case before the left-empty
case. Point classification uses the table and demands both operands even where
Boolean reasoning would permit a shortcut. The simple-terminal test precedes
the depth limit. Ignored surface identifiers/primitive-count metadata do not
acquire a new stopping role.

Keep binary64 operation grouping, sqrt, decimal conversion and source
positive digits/dot parser behavior. Extract the embedded c_aap literal into
a fixed profile file, preserving all 599 postfix codes and 300 primitive rows.
Each requested depth parses the scene in the source helper's written scope.
Compiled constant-input sharing/specialization may differ from the original
closed Haskell expression; no opaque barrier or identical cross-language
allocation cost is assumed.

Bounds, depths, primitive IDs and finest-grid counts fit signed 31-bit
integers. Within selected depths, coordinates/areas are dyadic and every final
area is an exact multiple of 4^-depth, with at most 24 fractional binary bits.
Validate exact scaled counts, not an arbitrary floating tolerance.

The original report uses shortest Double formatting. The portable driver
renders 24 fixed decimal places and checks the complete formatted value.
Every selected dyadic fraction terminates within those places; this is an
explicit output/library adaptation shared by all SML compilers.

### Inputs, profiles and result checks

| Profile | Repetitions | Depth sweep |
|---|---:|---|
| Smoke | 1 | 1 through 3 |
| Normal | 200 | 1 through 9 |
| Large | 200 | 1 through 12 |

Normal and large preserve the original 200 repetitions and NORM/SLOW sweep.
Smoke reduces source FAST 200-by-five explicitly. Scene coordinates and
distribution remain the fixed embedded source data, with no random generator
or external runtime facility.

For every repetition/depth, compute and validate the exact corrected-reference
finest-grid count and complete fixed-decimal output. Return validated
repetition/value/byte counts instead of repeated stdout. CLI/reference reads
move outside the loop, replacing repeated getArgs; timing/count reports
include the documented parsing/format/validation work.

Original/corrected observers record all thirteen areas through depth twelve
and complete adaptive tree shapes through depth nine. A separate direct union
membership scan over every finest-grid midpoint, with no CSG tree or adaptive
pruning, agrees on all ten independently checked depths through nine.
Synthetic circle/union/intersection/difference/full/empty controls and all
48 classification-table entries are observed independently.

### Compiler/runtime behavior and evidence scope

Investigate CSG simplification, memoized numeric fields, shared bounds,
subdivision spines, deep left-associated scene structure, parser/constant
specialization, allocation and formatting. These are source-based hypotheses
until separate counts or measurements establish narrower findings.

Direct tests preserve source demand order, ignored count metadata, midpoint/
rectangle short circuits, exact reference areas/shapes, zero work and
deliberately incorrect results. All checks remain valid on hosts exposing
compiler/runtime defects; no tolerance increase accepts them.

The first semantic matrix has one incorrect legacy 64-bit SML/NJ area check;
other groups pass and a repeated host-default group passes. Native O0/O2
labels do not represent different native compiler options. Canonical profile
outcomes, source identities, count/timing scopes and repository acceptance are
recorded separately. Individual large states do not establish the full
200-repetition selected large run.

### Literature and review scope

[Hartel and Langendoen (1993)](https://doi.org/10.1145/165180.165230)
provides the previously recorded collection/translation context. Specific CSG
tables, pruning, parser and spatial algorithms come from pinned source review.
No separate solid-modelling paper is claimed as the derivation of this code.
Corrected original observations, explicit table counterexamples and independent
geometric counts establish the recorded repair/correctness scope. Runtime
or compiler performance attribution remains a hypothesis.
"""
text=(s/'README.md').read_text();pos=text.index('\n## ');overview=''
for name in ['solid-lazy','solid-strict']:
 (s/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body)
 overview+='| ['+name+'](#'+name+') | [nofib Hartel solid](https://gitlab.haskell.org/ghc/nofib/-/tree/'+revision+'/spectral/hartel/solid) | Approximate a circle-union area with source CSG pruning, adaptive subdivision and '+('memoized'if name.endswith('lazy')else'strict')+' finite data. |\n'
 text+='\n## '+name+'\n\n'+body
(s/'README.md').write_text(text[:pos].rstrip()+'\n'+overview+text[pos:])
