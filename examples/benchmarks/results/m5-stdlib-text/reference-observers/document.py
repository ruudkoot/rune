from pathlib import Path
import csv,json
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/stdlib-text-originals'
revision=next(r['revision']for r in csv.DictReader((suite/'upstreams.tsv').open(),delimiter='\t')if r['source']=='sandmark')
profiles=json.loads((p/'profile-results.json').read_text())
descriptions={
'get':'Read characters at cyclic positions of the original fixed text.',
'set':'Mutate a per-call copy of the original text to spaces at cyclic positions.',
'cat':'Concatenate the fixed fish prefix and original byte sequence.',
'sub':'Copy two characters at cyclic source positions.',
'blit':'Copy thirty-two source characters into a newly filled byte destination.',
'concat':'Join the original four fish words with single-space separators.',
'iter':'Traverse the fixed text and invoke the source callback for every character.',
'map':'Map every original character to an exclamation mark.',
'trim':'Remove the original trailing newlines from the fixed trim input.',
'index':'Search from the beginning for the first lowercase r.',
'contains':'Test whether the fixed text contains a lowercase r.',
'uppercase_ascii':'Convert the original text to uppercase with ASCII rules.',
'split_on_char':'Split the original fixed text on single spaces, preserving empty fields.',
'compare':'Sum all ordered pairwise comparisons of words from the original text.',
'equal':'Count all ordered pairs of equal words from the original text.'}
text=(suite/'README.md').read_text();pos=text.index('\n## ');overview=''
for name in sorted({r['benchmark']for r in profiles}):
 family,key=name.split('_',1);anchor=family+'_get';ps=[r for r in profiles if r['benchmark']==name]
 description=descriptions[key];extra=''
 if key in ['get','set','sub','blit']:
  extra='The source loop starts at one. Get/set use i mod 574; sub uses i mod 572 and blit i mod 542, deliberately retaining the excluded last valid start. Smoke crosses these modulo boundaries.'
 if key=='set':extra+=' The original function is defined and configured but absent from the CLI dispatch; the reference exports and calls that function directly. A copy is made once per call, including zero iterations, and the final complete byte sequence is checked.'
 if key=='cat':extra+=' The original function is defined and configured but absent from the CLI dispatch; its callable body is preserved and named explicitly. The fish byte prefix is constructed once per call.'
 if key=='concat':extra+=' Bytes constructs its four arrays and separator once per call; String retains the word list expression inside the loop. The exact result is I AM A FISH.'
 if key in ['compare','equal']:extra+=' Split the words once per call, retain both nested left folds and their original argument order. Normalized comparisons sum to zero; ordered equal pairs total 133, independently counted from word multiplicities.'
 if key=='iter':extra+=' The original callback returns unit; the portable callback counts all 574 visits. This additional callback work is explicit.'
 body=f"""### Algorithm and workload

{description}

{extra}

### History, aliases and notices

This is selector {name} in [Sandmark's stdlib collection](https://github.com/ocaml-bench/sandmark/tree/{revision}/benchmarks/stdlib),
pinned at {revision}. Other selectors are separate workloads.
The Dune source credits adaptation from OCamlPro's benchmark repository;
the selected .ml/.inc files state no individual benchmark author or notice.
Preserve them and the suite Unlicense under {anchor}/upstream.

Pin OCaml 4.14.1 library source independently in {anchor}/DEPENDENCIES.json.
Bytes credits Xavier Leroy/INRIA, copyright 1996; String's implementation
credits Damien Doligez/INRIA, copyright 2014. Complete selected .ml/.mli
headers, LGPL 2.1 text and the linking exception are retained under
{anchor}/upstream-library. The library and benchmark notices are distinct.
The 574-byte Latin-like text is an embedded source literal, with no separate
dataset author or notice stated; INPUT-IDENTITY.json records its exact identity.

### Translation and variants

Use portable SML97 strings and Word8Array byte storage. Preserve operation
order, loop bounds, source text and per-call/global construction scopes.
Global text/byte input is shared; mutable bytes_set copies it per call.
No full OCaml library compatibility or identical storage/primitive cost is claimed.

Portable byte arrays may use different host packing and initialization.
Copy/sub/map use tabulation; blit/cat/concat use explicit element loops and
filled destinations in place of OCaml runtime block operations. Bytes.concat
retains one length pass and ordered segment copies. String.concat interleaves
separator list cells before the host String.concat, adding a temporary list.
String.split_on_char retains the source backward scan and empty fields.
ASCII uppercase and the exact five trim whitespace characters remain explicit.

OCaml's Sys.opaque_identity has no claimed identical SML97 barrier.
Full consumers and result checks add work and may expose constant results to
compiler specialization or hoisting. They do not establish equal work to the
original OCaml runtime. Standard comparisons use identical SML sources.

### Fixed inputs and checks

| Profile | Iterations | Published iterations | Expected count and digest |
|---|---:|---:|---|
"""
 for r in ps:body+=f"| {r['profile']} | {r['iterations']} | {r['published']} | {r['expected']} |\n"
 body+="""
The source parameter is an operation count; input text remains fixed.
Normal reductions and selected large counts are explicit rather than a
universal size argument. Full final large SML runs are unrecorded unless
listed separately in validation.

Check every scalar, complete produced string/byte sequence or split word list.
bytes_set additionally checks every final byte. FNV-1a-style Word32 mixing
consumes the checked observations; it is an added modular result format,
not source kernel arithmetic. Counts and source character operations fit
signed 31-bit integers. No floating-point tolerance applies.

### Validation and runtime concerns

Original OCaml function observers and independent byte/word models agree on
100 edge-count results and all 55 selected profiles. Observer-only hooks
capture discarded blit/callback results without adding an FFI requirement to
the SML program. The semantic target checks overlapping copies, isolation,
trim/ASCII behavior, empty split fields, cyclic boundaries, all selectors,
unchanged global input and rejection of corrupt character/final-array results.
Private pilot evidence and canonical wrapper checks have separate scopes.

### Literature and diagnostic interpretation

The preserved benchmark and OCaml library sources establish these algorithms
and adaptations. Original observations and independent models establish the
reviewed expected results. No separate string-algorithm paper review is claimed.
Packing, bounds checks, byte/string conversions, callback specialization,
temporary allocation, source barriers and the added complete consumers are
performance questions inferred from source; timing alone does not isolate them.
"""
 (suite/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body)
 text+='\n## '+name+'\n\n'+body
 overview+='| ['+name+'](#'+name+') | [Sandmark stdlib](https://github.com/ocaml-bench/sandmark/tree/'+revision+'/benchmarks/stdlib) | '+description+' |\n'
(suite/'README.md').write_text(text[:pos].rstrip()+'\n'+overview+text[pos:])
