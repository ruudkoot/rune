from pathlib import Path
suite=Path('examples/benchmarks')
body='''## Algorithm and workload

Parse a Mini Prolog command transcript, extend a sorted predicate database,
unify terms with an occurs check, enumerate query solutions, echo commands and
format answers. Consume and validate the complete interactive transcript through
a modular hash. Every repetition starts with the same immutable standard library.

## History, authorship, revision and variants

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/prolog.
Headers credit Mark P. Jones, November 1990. Examples describes an earlier
Orwell interpreter and the Haskell B version. Parse.hs credits Richard Bird's
Orwell parsing library; Interact.hs credits Bird and Wadler. README.nofib records
Will Partain's change from the illegal Haskell constructor operator :- to :==.
Retain all modules, original fixtures, standard library and historical notes
under prolog-lazy/upstream. No separate individual redistribution grant is
stated in those files; do not invent one. The examples and command data come
from the pinned application; no external Prolog corpus is introduced.

The active Engine.hs and excluded StackEngine.hs are byte-identical at the pin.
They share the prolog-lazy/prolog-strict implementation and retain both source
paths. PureEngine.hs is materially different: it builds and searches explicit
proof trees rather than an explicit stack, applies substitutions to remaining
goals at a different point, and has no cut predicate. Preserve it separately
as prolog-tree-lazy/prolog-tree-strict. Its answers for the supplied cut queries
differ from the active stack engine. They are checked against its own Haskell
implementation, not the stack fixtures. The supplementary source-variant
inventory records both relationships.

## Portable translation and evaluation

Keep the list-of-successes parser and all its alternative parse results,
first-success selection, term representation, function-valued substitutions,
composition order, occurs check and first-occurrence variable ordering.
Do not replace the interpreter with an association-map unifier or a different
Prolog engine. Predicate groups remain a sorted association list, keyed by
name rather than arity; clauses retain insertion order.

The stack engine retains explicit backtrack frames, fresh variable levels,
goal application order and the source cut operation, which clears the second
frame's alternatives while retaining the top frame. The proof-tree engine
retains memoized Done/Choice nodes and depth-first search. It does not acquire
the stack engine's cut behavior.

Both policies retain memoized parser alternatives, proof/search control streams
and output character streams. Lazy finite term payloads defer unused children
and substitution results; strict finite payloads construct them eagerly.
Potentially infinite search alternatives are not all forced by the strict
variant. Function-valued substitutions remain functions in both variants.
Difference-list output functions retain the source higher-order ShowS consumer.

Atoms use SML strings and selected input characters are ASCII. Runtime text is
converted to a shared character list once before the repetition loop. Parser
choice streams, terms, substitutions and database extensions are fresh for each
interpretation; the original immutable library/input are reused.

The bounded machine integers store source variable levels, positions and profile
counters; selected profiles fit signed 31-bit integers. Hash arithmetic uses
explicit Word64 modulo 2^64 on every host, matching the selected GHC 64-bit Int.
The driver checks every output character as it computes the forward hash, and
compares the result with an independent reverse polynomial calculation of the
reference transcript. It emits a stable repetition-count:hexadecimal-hash report.

The driver reads the library, input and reference once. Library clauses are
parsed once, as upstream. Remove the sign-on/library progress display from
accepted output, and replace the 200 printed decimal hash lines with the stable
report. The complete echoed/answer transcript being hashed is unchanged.
Retain backspace/delete handling, blank commands, syntax errors, continuation
semicolons, variable printing, database display and quit-tail demand.

The historical parser accepts some unusual empty names/queries and strips
literal spaces rather than arbitrary whitespace. Preserve and test those
behaviors. Command input exhausted without quit raises an error, matching the source's
partial reader under complete consumption. Selected source fixtures end in bye.

## Profiles and correctness

| Profile | Upstream command data | Repetitions |
|---|---|---:|
| Smoke | prolog.faststdin | 1 |
| Normal | prolog.stdin | 200 |
| Large | prolog.slowstdin | 200 |

The normal and large profiles retain their source iteration count and exact
command data. Smoke reduces only repetitions. All use the original standard
library and the suite's default resource limits.

Unmodified GHC runs match all three active-engine stdout fixtures exactly.
The proof-tree reference changes only the selected engine file, then uses its
own complete loop transcript. Export-only observers expose the original loop;
they add no alternate parser, unifier or printer.

All three complete transcripts agree for both SML payload policies and each
engine. Additional source-observed cases cover ambiguous parsing, empty
queries/names, backspaces, arity, aliases, numbered variables, clause order,
cut and quit-tail behavior. Tests cover substitution composition, cyclic
unification rejection, renaming, source cut-frame behavior, bad transcripts,
golden hash vectors and lazy/strict finite payload demand.

## Literature and diagnostic questions

[Bird and Wadler, An introduction to functional programming (1988)](https://www.research.ed.ac.uk/en/publications/an-introduction-to-functional-programming/)
supplies the bibliographic context for the credits in Parse.hs and Interact.hs.
The university record confirms author/title/year; the cited chapter contents
have not been reviewed here. The retained Examples document explains the two
specific inference engines.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides suite context.

Investigate parser branching and sharing, substitution closure chains,
higher-order printing, term allocation, retained backtrack frames, proof-tree
construction and early termination of alternative search. These questions
follow from source inspection. Reference agreement establishes selected
correctness; optimization/performance explanations require measurements.
'''
for tree in [False,True]:
 for mode in ['lazy','strict']:
  name=('prolog-tree'if tree else'prolog')+'-'+mode
  header='Inference engine: '+('explicit proof tree'if tree else'explicit backtrack stack')+'. Finite payload evaluation: '+mode+'.\n\n'
  (suite/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+header+body)
f=suite/'README.md';s=f.read_text();pos=s.index('\n',s.index('| [hidden-strict]'))+1
table=''
for tree in [False,True]:
 for mode in ['lazy','strict']:
  name=('prolog-tree'if tree else'prolog')+'-'+mode
  table+=f'| [{name}](#{name}) | [nofib Mini Prolog](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/prolog) | Interpret Prolog commands with {"proof-tree"if tree else"stack"} search and {mode} finite terms, checking the full transcript. |\n'
s=s[:pos]+table+s[pos:]
for tree in [False,True]:
 for mode in ['lazy','strict']:
  name=('prolog-tree'if tree else'prolog')+'-'+mode
  s+='\n## '+name+'\n\nInference engine: '+('explicit proof tree'if tree else'explicit backtrack stack')+'. Finite payload evaluation: '+mode+'.\n\n'+body.replace('## ','### ')
f.write_text(s)
