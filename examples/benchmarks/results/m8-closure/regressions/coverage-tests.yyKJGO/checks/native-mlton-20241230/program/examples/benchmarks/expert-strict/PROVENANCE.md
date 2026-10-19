# expert-strict provenance

### Algorithm and workload

Run the source animal-identification expert system: parse relations and rules,
rename variables, unify phrases with an occurs check, search and/or goals and
request answers as part of the result stream. Keep the binary-search-tree
knowledge/environment tables, lazy information table, fresh-variable stream,
duplicate-question filtering and solution/environment display. The information
table is built from the questions produced by the same inference computation;
this feedback is part of the workload, not ordinary eager input lookup.

### History, authorship and input origins

[Ian Holyer's expert source](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/expert), pinned at
b7391df4540ac8b11b35e1b2e2c15819b5171798, declares a March 1993 translation and
adaptation from his Functional programming with Miranda (Pitman, 1991).
Preserve all six Haskell modules and the README under expert-lazy/upstream.
Search.hs also records S. L. Peyton Jones's November 1999 extraction of shared
question text to avoid dependence on accidental compiler common-subexpression
elimination. Preserve that shared value explicitly.

The source runtime_files/animals and expert.stdin provide the fixed knowledge
and answer data. Retain their contents and source paths; no separate individual
dataset notice is stated. The supplied answer No is intentionally positive:
only a line whose words are exactly lowercase no is negative. Do not normalize
case or substitute a different interpretation of yes/no.

### Variants and translation decisions

-lazy memoizes phrase trees and child streams. -strict eagerly traverses each
finite phrase's children when its term is demanded. Both preserve lazy search,
question/answer feedback, table roots and delayed answer values: eager feedback
would force a question's answer before that question can be emitted. Explicit
control delays also preserve unused replies after a negative More answer.
The two policies have separate names and count records, with a poison-child
check demonstrating their intended evaluation difference.

The generic source table's key domain is specialized to the String keys used by
this program; retain lexical comparison and its binary tree, rather than replace
it with a host map/hash table. enterList remains lazy and first duplicate wins;
updateList retains insertion sorting, last-new-duplicate selection, sorted merge
and median balancing. Single updates, lookup, delete and entry enumeration are
also translated and checked. Retain unification's source zip truncation for
mismatched term arities; do not silently impose a new arity check.

Source strings are portable SML strings where bounded words/question formatting
need a complete value. Character, rule, answer and result streams retain explicit
memoized spines. Knowledge lines and answer words use their ASCII fixture
semantics. The driver builds one shared input-character stream and takes the
source i+9999 prefix separately for each repetition. Line splitting and answer
values remain delayed; no per-iteration full input conversion forces unused
answers. Each repetition rebuilds inference and its feedback table as in Main.
The question string is shared between display and information lookup.

### Inputs, profiles and result checks

Smoke uses one repetition instead of source FAST's 1000. Normal retains 10000
repetitions and large retains 50000. Preserve the source per-repetition prefix
parameter i+9999, fixed animal knowledge and exact answer bytes. This input is
shorter than every selected prefix, but the prefix computation is still present.
Selected indices and generated variable suffixes fit signed 31-bit arithmetic;
the total checked-character report uses IntInf as validation metadata.

The source prints length(process ...) each repetition: 526 for the supplied
answers. The port instead compares all 526 dialog characters on every repetition
and reports repetitions plus their total. This adds exact character validation
to the source length consumer and explicitly forces character values as well as
spines. Original GHC 9.4.7 matches every supplied FAST/NORM/SLOW length fixture;
an export-only observer provides the complete original dialog and five additional
answer scenarios. All checks are exact, with no numerical tolerance.

The 45-check target covers those six original dialogs, positive/negative answer
case, first/last duplicate behavior, update/lookup/delete/order, substitution,
occurs rejection, source arity behavior, question-before-answer demand, unused
answers, policy-specific phrase forcing, repetition and corrupt-dialog rejection.
Normal pilots use the original repetition count under explicit resource guards.
See the validation archive for actual compiler/engine results; full SML large
repetitions remain unrecorded unless listed explicitly.

### Literature and diagnostic questions

The source README credits Holyer's Functional programming with Miranda (1991).
Record this as its stated ancestry; the source, not an assumed textbook algorithm,
defines the exact unification, table and feedback behavior.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) provides suite
context. Search.hs's dated shared-string comment is source evidence for that
adaptation; it does not establish a current compiler performance cause.

Investigate phrase traversal, repeated substitution, table balance, delayed
input, knot tying, string sharing and stream allocation. These are source-based
hypotheses. Original-dialog agreement and explicit demand checks establish
correctness for the recorded cases. Runtime/count measurements are separate
observations, and fresh versus repeated execution retains its recorded mode.
