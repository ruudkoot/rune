from pathlib import Path
suite=Path('examples/benchmarks')
body="""### Algorithms and distinct workloads

The efficient sequential generator constructs integer endpoint arrays by
interleaving two random Float draws per edge/bit, generates weights afterward,
permutes vertex labels and then permutes edges. Preserve the source's zero-based
labels and stable Array.fast_sort ordering for equal random keys.

Kernel 1 constructs an array of adjacency lists from supplied edges. It removes
self-loops, retains duplicate edges, inserts both directions and prepends in
source order. Its allocated extent is the observed maximum vertex plus one.
The normal fixture requests 4096 possible labels but allocates 4095 rows because
the largest label is absent. Preserve that source behavior.

The standalone kronecker prototype differs materially. It draws a full first-bit
array before the second-bit array, repeatedly appends/copies float arrays,
keeps one-based coordinates, independently permutes the two coordinate rows,
transposes, permutes edge rows and transposes back. Its List.sort compares the
whole random-key/payload pair, including numeric payloads on ties. Preserve the
quadratic append construction and distinguish it from the efficient generator.

### History, names, provenance and notices

Pinned Sandmark revision 5605805954a00497ed197c930641cddd580e1507,
benchmarks/graph500seq. Audit all three executables: gen.exe, kernel1_run.exe and
kronecker.exe, plus interfaces and the pure GraphTypes interface located under
graph500par. That shared interface defines numeric types; it requires no parallel
execution facility. The prototype comment credits support from PRISM Lab,
IIT Madras and OCaml Labs without naming an individual author.

Rune names graph500-gen and graph500-kernel1 retain the published run-plan
aliases graph500_gen and graph500_kernel1/graph500_seq_kernel1. Original executable
aliases gen and kernel1_run remain documented. kronecker keeps its original name.
The three programs share provenance and suitable support, not an implementation
that erases their different workloads.

All original programs/interfaces and the collection license remain under
graph500-gen/upstream. Sandmark's collection license is the Unlicense.
Individual graph files state no additional grant. Imported OCaml stdlib sorting,
random and Marshal-format material keeps its separate INRIA 1996 LGPL 2.1 notices
and OCaml linking exception, complete original files and license text.
Sorting is attributed to Xavier Leroy; the existing random helper retains its
Damien Doligez attribution. Do not replace these notices with the collection
license. Stock OCaml 4.14.1 revision/source identities are recorded.

### SML97 translation and evaluation

All kernels, input generation, formatting, binary translation and checking use
SML97. Preserve nested arrays, unboxed RealArray rows, association-list adjacency,
source mutation and copying, sort algorithms/cutoffs and tie behavior.
The stdlib Array.stable_sort and alternating List.stable_sort are translated
rather than replace them with a different sorting algorithm.

Reuse the reviewed OCaml Random draw implementation with a fresh default-state
snapshot for every benchmark invocation. The gen fixture adapter removes
Random.self_init to make its input reproducible. The prototype already uses
the default state. Record the complete state identity; no profile result or
generated graph is cached across invocations.

The efficient generator's dimensions use integer shifts; the prototype derives
them with floating power followed by truncation. Keep both numeric choices.
Selected labels and 30-bit random keys fit signed 31-bit SML int. Hashes use
explicit Word64 modular arithmetic, and binary weights use binary64 semantics.

A portable codec handles the actual finite, unshared edge-array Marshal shape:
small header with both receiver-word counts, compact/32/64-bit block headers,
nonnegative selected integer labels and finite Double fields. It validates
header lengths, object counts, shape, minimum body size and EOF. It is a bounded
translation module rather than an OCaml object runtime.

Optional packing structure names differ across hosts. The codec therefore uses
one common SML97 decomposition/scaling and IntInf/Word64 representation algorithm.
Its valid exact-integer TO_NEAREST conversion and header word literal are identical
on every compiler. Separate optional-API and numeric-control failures remain
in the evidence. No host-conditioned arithmetic or tolerance change is used.

Unix clocks and volatile progress/timing messages are replaced by suite process
measurements and stable result reports. Generation still writes edges.data;
kernel 1 reads its original binary input; the prototype writes kronecker.txt.
Its source exits from the CSV writer, whereas the adapter closes the file and
returns so the complete output can be validated. Filenames and working directories
are fixed by the runner.

### Profiles, source parameters and data origins

| Profile | Efficient generator / kernel 1 | Prototype |
|---|---|---|
| Smoke | scale 6, edge factor 4 | scale 3, edge factor 1 |
| Normal | scale 12, edge factor 16 | scale 8, edge factor 4 |
| Large | scale 14, edge factor 16 | scale 10, edge factor 4 |

The efficient normal profile retains gen's command-line defaults.
The source build/run plans also select 21/16 for gen/kernel 1 and 12/10 for the
prototype. Those larger parameter sets remain explicit future calibration/data
candidates, separately from the practical fixed profiles above. Keep both scale
and edge factor as meaningful upstream parameters. The ignored sequential
-ndomains flag is not a new parallel workload.

Kernel inputs are generated by the original OCaml 4.14.1 serializer using the
reviewed default state. DATA-IDENTITIES.json records every file's source revision,
origin, size, SHA-256 and format magic. These are narrowly reviewed binary source
data. Executable/object/cache artifacts are excluded. Data is synthetic; there
is no separate dataset notice. Preserve the original code and its notices.

### Correctness and measured observations

Generation hashes every encoded output byte and reports edge/byte counts.
Kernel 1 reports edge, vertex and arc counts plus an ordered hash of endpoint
labels and floor(weight*1e8). Every consumed weight must be finite in [0,1).
This numeric check also detects incorrect float interpretation when a broken
encoder/decoder could otherwise cancel in a byte roundtrip.
The prototype validates its complete six-decimal CSV by byte count and hash.
All result checks are exact; no numerical tolerance permits different integer
dimensions, endpoint order, encoded weight bits or source CSV.

Original generated files and all selected prototype CSV outputs agree
byte-for-byte with final portable Rune pilots, including normal and large.
Original Kernel1Seq observations agree with an independent Python decoder and
append/reverse adjacency model on all profiles. Full normal and selected large
Rune calibration passes in a recorded memory/time guard.

The 312-check target covers every smoke edge and weight, complete binary/CSV
fixtures, empty and integer-boundary codecs, malformed/truncated/extra data,
duplicate/self-loop/order controls, 31 list/array sort sizes and forced key ties.
Standalone numeric probes separate source dimension sensitivity, integer-rounding
differences and word construction. Canonical host/count results are recorded as
they finish. Failed primary checks cannot supply accepted timing samples.

Current controls observe SML/NJ Math.pow(2,3) just below eight, so the source
truncation chooses seven; Poly/ML TO_NEAREST changes some already integral
53-bit reals; legacy 32-bit SML/NJ changes the header word in literal/shift
constructions. Preserve the valid program operations and exact findings.
Do not infer one common compiler mechanism from these different observations.

### Literature and diagnostic questions

The [Graph500 specification](https://graph500.org/?page_id=12) provides generator
and graph-construction context. The retained Sandmark source defines these
particular sequential implementations and their differences. Suite reports use
the common SML process-measurement contract; specification-wide search/TEPS
measurements belong to a separate protocol.

Investigate random draw cost, float representation, sorting stability, repeated
array copying, binary translation, adjacency-list allocation and degree-driven
object lifetimes. These are source-based hypotheses until supported by separate
measurements. Complete source agreement is a correctness finding, not an
explanation of a performance difference.
"""
f=suite/'README.md';text=f.read_text();pos=text.index('\n## ',text.index('| [kb_no_exc]'))
table=''
for name,description in [
 ('graph500-gen','Generate deterministic weighted Kronecker edges with the efficient source algorithm and validate the exact serialized output.'),
 ('graph500-kernel1','Build ordered undirected adjacency lists from original binary edge fixtures, preserving duplicate edges and self-loop removal.'),
 ('kronecker','Run the distinct append-based floating-array Kronecker prototype and validate its complete CSV output.')]:
 table+=f'| [{name}](#{name}) | [Sandmark sequential Graph500](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/graph500seq) | {description} |\n'
 (suite/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body)
text=text[:pos].rstrip()+'\n'+table+text[pos:]
for name in ['graph500-gen','graph500-kernel1','kronecker']:text+='\n## '+name+'\n\n'+body
f.write_text(text)
with(suite/'audit.md').open('a')as f:f.write("""
## Sequential Graph500 naming and variants

| Original executable | Run-plan aliases | Rune name | Disposition |
|---|---|---|---|
| graph500seq/gen.exe | graph500_gen | graph500-gen | Import efficient integer-row generation and original binary output. |
| graph500seq/kernel1_run.exe | graph500_kernel1, graph500_seq_kernel1 | graph500-kernel1 | Import list-array adjacency construction over original deterministic Marshal fixtures. |
| graph500seq/kronecker.exe | kronecker | kronecker | Import the distinct floating-array append/permutation prototype. |

The shared GraphTypes interface in graph500par contains only numeric type
aliases. Sequential ports require no parallel runtime. Their profile choices,
larger configured parameter candidates, source notices, numeric differences
and every driver/data adaptation are recorded in their provenance sections.
""")
