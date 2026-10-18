from pathlib import Path
import csv
suite=Path('examples/benchmarks');revision=next(r['revision']for r in csv.DictReader((suite/'upstreams.tsv').open(),delimiter='\t')if r['source']=='nofib')
body=f"""### Algorithm and workload

Enumerate the source non-delay schedules of fork/join job graphs on two
simulated processors. Preserve job phases, owner affinity for joins, processor/
queue reversal, all allocation alternatives, event-step advancement and the
source zero-sentinel minimum. This is sequential simulation and search, with
no operating-system parallelism.

### History, naming and notices

[The nofib Hartel sched source](https://gitlab.haskell.org/ghc/nofib/-/tree/{revision}/spectral/hartel/sched)
is pinned at {revision}. Its generated Main.hs states no individual author
or separate program license. Preserve the complete source, Makefile, original
FAST/NORM/SLOW fixtures and parent Fast2haskell shim. Collection attribution
does not establish an individual program author.

sched-lazy and sched-strict retain the established sched name and distinguish
finite data policies. They are not duplicates of a task scheduler using real
threads. The shim's miraseq is a no-op; sandwich metadata are never demanded.
No compiler/runtime prerequisite is introduced.

### Translation, sharing and variants

Explicit memoized delays preserve the search tree and its branch-control
structure in both variants. Finite job definitions/status fields, processor
records and list heads/spines use lazy or strict policies. Global definitions
and the initial processors remain shared across repetitions; each search is
fresh. Strict initialization forces the finite definition graphs, while lazy
initialization demands only reachable fields. The 55 named definitions are
emitted in dependency order to express source forward references in SML.

The existing reviewed finite-list support from IDA is reused. Paired outputs
of selection/processing remain shared, with separate memoized projections.
Keep unused processor IDs, parents, join durations and child selectors pending
in the lazy policy. Preserve empty/phase-one short circuits and no-op sandwich
hint demand, including in the strict finite variant. Bounded numeric search
controls are strict SML values; hint expressions retain explicit delays.

Original graph labels are selectors, not a recomputed node count: the inputs
labelled ten and fourteen contain nine and thirteen defined jobs respectively.
Keep their actual topology, durations and IDs. All selected kernel arithmetic
fits signed 31-bit integers. Added observation totals use IntInf and ordered
tree hashes use Word32. No floating tolerance is involved.

### Fixed profiles and correctness

| Profile | Repetitions | Source graph selector | Checked minimum cycles |
|---|---:|---:|---:|
| Smoke | 1 | 3 | 60 |
| Normal | 100 | 11 | 218 |
| Large | 1 | 14 | 267 |

Smoke reduces the source FAST 200-by-10 setting. Normal retains its original
100-by-11 setting. Selected large studies the larger supplied search tree;
the original SLOW 500-by-11 fixture is retained as a separate scale reference.
Preserve independent repetition and graph parameters, rather than introducing
a universal size argument.

Each repetition checks the exact minimum against reviewed original and
independent values. The source ASCII sumcode is not the sole oracle: different
numbers can share it. The driver returns the count and sum of verified minima,
suppresses repeated stdout and reads arguments once outside the loop instead
of repeated getArgs. Zero repetitions leave search computation undemanded.

Original export-only observers record complete tree counts, min/max/sums and
ordered hashes at 23 graph/threshold combinations. The larger labelled graph
has 287625 leaves. An independent event/DAG model with affinity and non-delay
assignment agrees on all seven supplied graphs, using state memoization rather
than the benchmark's schedule tree. Full-tree observations validate the port's
ordering separately from minimum agreement.

### Compiler/runtime behavior and validation

Investigate persistent list rebuilding, paired-result sharing, suspended finite
fields, search-tree lifetimes, branch choices, closure specialization and
strict versus delayed initialization. These are source-based hypotheses until
supported by source-level compiler analysis or separate measurements.

The semantic target compares original tree observations across both policies
and checks unused fields, sharing, no-op hints, zero work and incorrect-minimum
rejection. Rune normal pilots retain the original 100 repetitions. Source-order
setup diagnostics remain separate from final checks; full configuration and
selected large coverage are recorded explicitly in the validation ledger.

### Literature and evidence scope

[Hartel and Langendoen (1993)](https://doi.org/10.1145/165180.165230), collection
metadata/abstract reviewed in the initial survey, supplies translation context.
The pinned program establishes this particular scheduling policy and data;
the independent DAG oracle does not replace its enumerating algorithm.
Original and independent results establish correctness, while performance
mechanism claims remain hypotheses.
"""
text=(suite/'README.md').read_text();pos=text.index('\n## ');overview=''
for name in ['sched-lazy','sched-strict']:
 (suite/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body)
 overview+='| ['+name+'](#'+name+') | [nofib Hartel sched](https://gitlab.haskell.org/ghc/nofib/-/tree/'+revision+'/spectral/hartel/sched) | Enumerate two-processor fork/join schedules with '+('memoized'if name.endswith('lazy')else'strict')+' finite job data. |\n'
 text+='\n## '+name+'\n\n'+body
(suite/'README.md').write_text(text[:pos].rstrip()+'\n'+overview+text[pos:])
