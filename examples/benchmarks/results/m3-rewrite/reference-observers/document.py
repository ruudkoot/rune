from pathlib import Path
r=Path.cwd();s=r/'examples/benchmarks'
url='https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/rewrite'
body='''### Algorithm and workload

Complete the three free-group axioms with Knuth–Bendix completion, recursive
path ordering with lexicographic extension, substitutions and unification,
critical-pair generation and a cost-sorted agenda. Index rewrite rules in the
source discrimination net. Normalize repeated queries proving
I(a*b)=I(b)*I(a). Preserve the generated ten-rule theory, equation numbers,
rule order, variable-standardization suffixes and source left-biased tactics.

### History, names and notices

[The nofib spectral/rewrite source](URL) is pinned at
b7391df4540ac8b11b35e1b2e2c15819b5171798. Its April 23, 1991 correspondence
and Orwell heading credit Mike Spivey, Programming Research Group, University
of Oxford; the Haskell conversion is credited to partain. Preserve those
credits and the complete literate source, Makefile and fixtures. No separate
program copyright/license declaration or dataset notice is stated there;
do not invent one or infer authorship from the collection name.

The name rewrite has no collision in the pinned naming inventory, so the
ports are named rewrite-lazy and rewrite-strict. This is a free-group
completion workload, distinct from classic theorem-proving/rewriting programs
and Sandmark's separately sourced completion programs. Similar algorithm
families do not establish exact duplication.

### Translation and variant decisions

The lazy variant memoizes expression roots, finite child-list heads/spines,
substitutions, discrimination-net branches, agendas, candidate streams and
computed agenda costs. A singleton agenda need not evaluate its unused cost.
The source map/zip classification is expressed as shared lazy tagged pairs;
filter order and predicate sharing remain, while its separate Boolean-map
spine is omitted.
The strict variant forces finite expression children when their constructor
root is requested. Both retain lazy net/control roots and short-circuit
search. Lexicographic comparison skips unused tails; matching/unification
retain the source zipped-arity truncation and association-list lookup order.
Substitution composition, persistent replacement and higher-order parser/
rewriting callbacks remain. No hash-consing or union-find replacement is added.

Keep the source global completion as a shared memoized delay across queries
and repeated Benchmark.run calls. Zero queries leave both axioms and completion
undemanded. Each call constructs the source finite take/repeat query stream;
the repeated pair is shared within it. No normalized-query result cache is
introduced. Global source completion sharing is deliberate and matters to
fresh versus repeated-process measurements.

SML strings represent finite atomic names and source text, with portable
substring operations in the same backtracking parser combinators. This changes
character-list representation/allocation, not the grammar or prefix parsing.
Inactive multiset ordering and generic helpers remain in the archived source;
the benchmark uses recursive path ordering's lexicographic extension.
The source NOINLINE annotation has no claimed identical portable SML switch;
record options and investigate optimizer effects instead of asserting that all
compilers perform identical work.

### Inputs and exact checks

Smoke selects one query, reducing source FAST's 20000; normal retains 250000
and large retains 1200000. Inputs are fixed source axiom/query strings, with
no external dataset, random seed or clock-dependent stopping condition.
The driver accepts canonical decimal counts from zero through 1200000;
other arguments are outside its fixed-profile contract. Driver counts fit
signed 31-bit integers.

The source Boolean True remains the reported result. Additionally check the
entire normalized query tree on every successful repetition and the number of
observed results; an incorrect term cannot contribute a measurement.
Original GHC 9.4.7 matches all FAST/NORM/SLOW fixtures. An export-only original
observer records the complete ten-rule theory and sixteen normalization cases.
An independent signed-letter cancellation model and original normalization
agree on 128 depth-bounded generated terms (seed 19790601).

The 344-check target covers both variants: exact numbered theory, 144 full
normal forms, source substitution/matching/unification behavior, occurrences,
persistent replacement, field demand, short-circuiting, unneeded zero-query
completion and incorrect-result rejection. Native/compiler outcomes are
recorded separately from development pilots. Full final SML large repetitions
remain unrecorded unless explicitly listed in validation.

### Literature and diagnostic interpretation

[Knuth and Bendix (1970)](https://www.cs.tufts.edu/~nr/cs257/archive/don-knuth/knuth-bendix.pdf)
gives the completion/common-normal-form foundation, including group equations.
[Dershowitz (1982)](https://www.sciencedirect.com/science/article/pii/0304397582900263)
discusses orderings used to justify rewrite termination. These give context;
the pinned program determines its specific ordering extension, agenda and demand.

Spivey's preserved 1991 description establishes the program's Orwell history,
free-group problem and use of Maybe/combinators. Partain's nofib paper supplies
suite context, not measured conclusions about this port. The source defines
this particular completion strategy and ordering; exact theory and independent
normal forms support the recorded behavior.

Investigate higher-order specialization, lazy allocation/sharing, persistent
substitutions, discrimination-net traversal, backtracking parser allocation
and repeated-query optimization. These are source-based diagnostic hypotheses.
Measurements must establish their actual costs; ratios alone do not identify
a compiler or collector cause. Retain all samples and distinguish fresh runs
from repeated execution with cached completion.
'''.replace('URL',url)
f=s/'README.md';text=f.read_text();pos=text.index('\n## ');rows=''
for mode in ['lazy','strict']:
 name='rewrite-'+mode
 (s/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body)
 rows+='| ['+name+'](#'+name+') | [nofib]('+url+') | Complete free-group rewrite rules and normalize repeated queries with '+mode+' finite expression fields. |\n'
 text+='\n## '+name+'\n\n'+body
f.write_text(text[:pos].rstrip()+'\n'+rows+text[pos:])
