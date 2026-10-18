from pathlib import Path
import csv
s=Path('examples/benchmarks');revision=next(r['revision']for r in csv.DictReader((s/'upstreams.tsv').open(),delimiter='\t')if r['source']=='nofib')
body=f"""### Algorithm and workload

Label four-neighbor connected black regions in tiled binary images. Preserve
horizontal run extraction, unique row/run labels, balanced recursive field
union, persistent labelled-set trees, boundary merging, component lookup and
label mapping. The original zift operation crops the trees inspected by
recursive label mapping; it is not replaced by a mutable union-find algorithm.

### History, names and source variants

[nofib Hartel comp_lab_zift](https://gitlab.haskell.org/ghc/nofib/-/tree/{revision}/spectral/hartel/comp_lab_zift)
is pinned at {revision}. Preserve the complete generated module, Makefile,
FAST/NORM/SLOW fixtures and parent Fast2haskell shim. The program heading
states no individual author or separate notice; collection/helper credits
do not establish individual authorship. No external dataset is needed.

The established comp_lab_zift name denotes the original sifting mode.
comp_lab_nozift retains the source f_no_zift alternative, separately named
because it skips generator demand and local tree pruning. The source helper
f_main_field' selects that alternative with a negative tiling argument, while
the benchmark Main itself tiles positive sizes. The portable explicit mode
uses positive tiling and the original f_comp_lab_diff' plus f_no_zift, with
the same complete renderer. It does not run a divergent negative repetition
loop or invent another component-labelling algorithm.

Each mode has explicit -lazy/-strict finite-data names. The unused parallel
prediction fields and sandwich calls use the source no-op miraseq shim.
Execution is sequential and requires no parallel runtime.

### Translation, sharing and tree semantics

Use SML97 tagged datatypes and policy-controlled memoized finite lists, trees,
labels, ranges, fields and paired results. Strict variants materialize these
finite values. Paired splits, generator views, shared base-image handles and
ignored prediction hints retain delayed control where required. Preserve
memoized mapped integer fold accumulators, rather than forcing every lazy
accumulator at construction.

Base figures remain shared global values; each requested tiling and labelling
computation constructs fresh derived data. Tiling grows both width and height.
Repetitions, tiling factor and branch threshold remain distinct parameters.
ASCII base strings replace literal Haskell character lists at the input
boundary; rendering uses SML strings and documented finite bridges.

Retain source tree behavior even where its names suggest a more general set
operation: merging does not remove duplicate keys; selecting a leaf outside
the interval retains it; cropping keeps the global representative while
changing local membership. The filter_set helper maps over objects rather
than deleting nonintersecting objects. Keep the original representative and
object-list ordering, avoiding a substitute canonical/minimum-label scheme.

Guarded disjoint borders must not find objects or demand their labels.
Ordered-tree union must avoid its unused flatten/sort fallback. Membership
and selection avoid irrelevant subtrees. Non-sifting label mapping leaves
generator arguments undemanded; sifting needs them. Ignored sandwich prediction
values remain unforced in both policies.

Indices, label arithmetic, source checksums and selected aggregate byte counts
fit signed 31-bit integers. No floating-point, modular or arbitrary-precision
kernel arithmetic is introduced.

### Inputs, profiles and complete checks

| Profile | Repetitions | Tiling factor | Branch threshold |
|---|---:|---:|---:|
| Smoke | 1 | 1 | 0 |
| Normal | 100 | 5 | 1280 |
| Large | 100 | 9 | 2304 |

Normal and large retain the original fixed 100 repetitions and NORM/SLOW
tiling parameters. Their threshold is the source factor times the 256-pixel
base area. Smoke reduces original FAST 100-by-two to one-by-one and explicitly
selects zero threshold to exercise recursive sifting/control. Both modes
use identical selected images and thresholds.

Require the complete original component image, raw run labels and every final
object-tree rendering to agree byte for byte, then check the source sumcode.
The coarse original checksum is not the sole oracle. Each repetition consumes
and validates its complete output; the driver returns checked repetition/byte
counts instead of repeated stdout.

Argument/reference reads move outside the repetition loop, replacing repeated
getArgs. Whole output strings and equality checks add validation/retention work.
No opaque optimization barrier is assumed: repeat-invariant specialization or
hoisting remains a compiler question to examine through separate counts.
All compilers in the standard report receive identical SML sources.

Unmodified Haskell FAST/NORM/SLOW outputs match all source fixtures.
Read-only observers cover 46 complete states across five base figures,
thresholds, tiling factors and both modes. An independent four-neighbor BFS,
row-run extractor and tree-membership/split-invariant checker validates all
129950 observed pixels. The oracle does not use the benchmark's persistent
tree union or sifting algorithms.

### Compiler/runtime concerns and recorded validation

Investigate persistent allocation, shared splits, delayed paired fields,
integer fold chains, tree lookup/merge, sifting, closure specialization,
strict materialization and whole-string consumers. These are source-based
hypotheses until source/count/timing evidence supports a narrower finding.

Direct tests preserve source duplicate/leaf/representative quirks and check
ignored hints, unused generators, dead subtrees, memoization, zero work and
deliberately wrong full results/checksums. Complete state and profile checks
remain separate from their smaller semantic controls. Native group labels
use host-default settings; Rune O0/O2 levels are explicit.

Private normal pilots preserve all 100 repetitions in both modes/policies.
Canonical engine/host outcomes, counts and repository acceptance are recorded
separately in the validation ledger. Single large states do not establish
completion of full 100-repetition selected large runs.

Poly/ML 5.9.2 compiles the full kernel and all four normal application pilots,
but reports an entryNumber compiler internal error for an auxiliary strict-tree
test with external tuple projection. The first 98 assertions, including all
92 complete original-state comparisons, compile and pass as a diagnostic
prefix. Preserve the full valid test and failure; the prefix does not replace
the full semantic target. Other host/engine outcomes are recorded separately.

Initial tuple projections left their pair arity unspecified; explicit pair
and integer-sequence annotations resolve that portability issue. Earlier
compile attempts remain separate development evidence.

### Literature and evidence scope

[Hartel and Langendoen (1993)](https://doi.org/10.1145/165180.165230)
supplies collection/translation context at the survey scope recorded in the
suite bibliography. The particular connected-component algorithm, object
representation, thresholds and ignored scheduling wrappers come from pinned
source inspection. No separate image-labelling paper is claimed as reviewed
for this program. Original/independent result agreement establishes
correctness at the recorded inputs; individual performance effects remain
hypotheses pending separate evidence.
"""
text=(s/'README.md').read_text();pos=text.index('\n## ');overview=''
for name in ['comp_lab_zift-lazy','comp_lab_zift-strict','comp_lab_nozift-lazy','comp_lab_nozift-strict']:
 (s/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body)
 overview+='| ['+name+'](#'+name+') | [nofib Hartel comp_lab_zift](https://gitlab.haskell.org/ghc/nofib/-/tree/'+revision+'/spectral/hartel/comp_lab_zift) | Label tiled binary-image components with '+('memoized'if name.endswith('lazy')else'strict')+' persistent data '+('and source sifting'if'_zift-'in name else'without source sifting')+'. |\n'
 text+='\n## '+name+'\n\n'+body
(s/'README.md').write_text(text[:pos].rstrip()+'\n'+overview+text[pos:])
