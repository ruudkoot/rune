from pathlib import Path
import csv,json
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/stdlib-str-originals'
revision=next(r['revision']for r in csv.DictReader((suite/'upstreams.tsv').open(),delimiter='\t')if r['source']=='sandmark')
profiles=json.loads((p/'profile-results.json').read_text());published=json.loads((p/'published-counts.json').read_text())
descriptions={'str_regexp':'Compile the original nonempty literal regular expression on each iteration.','str_string_match':'Test the original expression against the beginning of the fixed source text.','str_search_forward':'Search forward for the original literal phrase in the fixed source text.','str_string_partial_match':'Test complete or truncated-prefix matching at the beginning of the fixed source text.','str_global_replace':'Replace every occurrence of the original literal phrase with a period.','str_split':'Split the fixed source text with the original absent at-sign expression.'}
text=(suite/'README.md').read_text();pos=text.index('\n## ');overview=''
for name,description in descriptions.items():
 body=f"""### Algorithm and workload

{description}

Preserve test_regex Novum Site and the exact 574-byte source text. The source
starts its loop at one. Compile on every iteration only for str_regexp;
other selectors compile once per call. str_split uses @ instead of test_regex.
The fixed text starts with In, so both initial-match selectors return false.
Forward search finds position 274; replacement substitutes that ten-byte phrase.

### History, variants and notices

Selector {name} comes from [Sandmark stdlib](https://github.com/ocaml-bench/sandmark/tree/{revision}/benchmarks/stdlib),
pinned at {revision}. These are separate configured selectors, not duplicates.
The Dune source credits adaptation from OCamlPro's repository; the individual
source states no author or separate notice. Preserve it, str.inc and the
Sandmark Unlicense in str_regexp/upstream.

Pin the OCaml 4.14.1 Str implementation, interface, C matcher and full LICENSE
independently under str_regexp/upstream-library; DEPENDENCIES.json records their
identities. Those sources credit Xavier Leroy/INRIA, copyright 1996, under
LGPL 2.1 with the linking exception. The original Str engine and benchmark
notices are distinct. The input literal and its attribution limits are recorded
with bytes_get/string_get; no external dataset is required.

### Translation decisions

Reuse the suite's portable regex adapter, with literal compilation, ordered
matching, leftmost search and nonempty constant replacement. Add a
literal-sequence partial matcher, source-style split control and explicit
last-match position state. Partial matching succeeds when text ends at a
matching prefix. Split removes one leading delimiter match and a trailing
empty field while preserving empty fields between adjacent single delimiters.
No full Str API, captures, backreferences or empty-pattern support is claimed.

OCaml's internal bytecode engine, native matcher and packed regexp representation
are replaced by SML expression lists and substring indices. Explicit position
vectors represent the source last-search-result array. Preserve compile/call
scopes and search/replace order; record this library replacement when comparing
implementations. No FFI or compiler/runtime prerequisite is introduced.

### Inputs and correctness

| Profile | Iterations | Published iterations | Expected count and digest |
|---|---:|---:|---|
"""
 for r in [x for x in profiles if x['benchmark']==name]:body+=f"| {r['profile']} | {r['iterations']} | {published[name]} | {r['expected']} |\n"
 body+="""
Counts are explicitly selected source parameters; input text and expressions
remain fixed. Normal reductions and selected large counts are documented.
Full final large SML repetitions remain unrecorded unless listed separately.

Check exact booleans/positions, complete replaced text and split lists.
Compiled regex consumers inspect the complete portable literal representation.
Added Word32 mixing consumes the checked observations. Original compile
observers verify matching behavior and source compile counts without claiming
an identical internal regexp representation. Added consumers and the missing
identical Sys.opaque_identity barrier can affect specialization or hoisting.

### Recorded and planned validation

Original OCaml functions agree with independent literal models on eighteen
edge-count and fourteen selected profile results. Twenty-one further original
library observations cover complete/partial matches, offsets, absent/overlapping
searches, repeated replacement and split boundaries. The 42-check target also
rejects a corrupt position and a negative partial-match index. Canonical wrapper
results are distinguished from private pilots in the validation ledger.

### Literature and diagnostic interpretation

The preserved Str implementation establishes the original call scopes and
split/match state behavior. The suite regex adapter documentation describes
its bounded replacement. Original observations and independent literal models
support correctness. No separate regex-engine paper review is claimed.
Compilation, literal scanning, result-vector allocation, substring copying and
consumer specialization are source-based performance hypotheses; measurements
do not isolate the cost of an individual mechanism.
"""
 (suite/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body);text+='\n## '+name+'\n\n'+body
 overview+='| ['+name+'](#'+name+') | [Sandmark stdlib](https://github.com/ocaml-bench/sandmark/tree/'+revision+'/benchmarks/stdlib) | '+description+' |\n'
(suite/'README.md').write_text(text[:pos].rstrip()+'\n'+overview+text[pos:])
