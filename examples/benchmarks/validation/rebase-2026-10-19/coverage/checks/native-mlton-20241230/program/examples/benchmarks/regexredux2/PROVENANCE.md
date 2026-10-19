# regexredux2 provenance

### Algorithm and workload

Run the regex-redux pipeline: strip FASTA headers/newlines, count nine DNA motif
patterns one at a time and apply the five source substitutions in order. Print
all pattern/count pairs and the original, stripped and final lengths. Preserve
case-folded motif counting, case-sensitive substitutions and the source count
loop's next search position at match-start+1, including overlapping matches.
Global substitution resumes at the previous match end.

### History, names and notices

Source [Sandmark benchmarksgame/regexredux2.ml](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/benchmarksgame/regexredux2.ml), pinned
at 5605805954a00497ed197c930641cddd580e1507. Christophe Troestler contributed the
regex-dna ancestor; Roman Kashitsyn adapted mutation to Bytes. The established
workload is regex-redux; retain regexredux2 as the pinned executable variant name
and document regex-dna as ancestry rather than an exact duplicate. The required
source pipeline differs from other historical regex-dna substitution programs.

The pinned fasta3 generator credits Troestler, Mauricio Fernandez and Tony
Tavener. Preserve both original programs, Dune, README, Revised BSD LICENSE and
the Sandmark root notice. The individual BSD notice names Brent Fulgham and
Isaac Gouy. All input profiles are generated from the pinned fasta3 source with
its fixed initial random state and original probability tables. Record full
file hashes and byte lengths in DATA-IDENTITIES.json; these are generated text
data, not embedded executable artifacts.

### Portable library replacement

The original uses OCaml Str's native library. A portable SML97 adapter implements
the precise fragment used here: literal characters, enumerated/negated character
sets, dot excluding newline, greedy star with backtracking, ordered escaped
alternatives, line anchors, ASCII case folding, forward search and constant
replacement. It preserves regular-expression matching instead of replacing
motif searches with direct nucleotide counts or a combined scan. Compile each
motif at its source call site and run one pattern at a time. This adapter is
scoped to these fixed expressions; it does not claim the full Str API, grouping,
backreferences, ranges or empty-match replacement support.

The engine uses immutable expression lists and explicit substring indices;
OCaml Str's internal engine/representation is not reproduced. Record this
library replacement when interpreting measurements. Read the selected fixed
file with portable TextIO.inputAll rather than the original incremental
Bytes/Buffer input loop. Preserve complete input materialization, strict
pipeline order, original replacement strings and immutable intermediate text.
The driver suppresses repetitive stdout, compares the complete report exactly
and returns its checked length. All byte lengths and counts fit signed 31-bit
integers for these profiles. No numerical tolerance applies.

### Inputs and profiles

Smoke generates FASTA with N=100 (1095 bytes). Normal uses N=50000 (508411 bytes),
and large uses N=500000 (5083411 bytes). The pinned program expects an input
named input5000000.txt generated with N=5000000. These are explicit smaller
profile selections, retaining the generator, seed, sequence proportions and
line widths; they do not claim to measure the published 50 MB input. Profile
filenames are manifest parameters rather than a hardcoded working-directory
filename. The source is processed as a whole file, with no universal size loop.

Expected complete reports contain 259, 274 and 286 characters respectively.
Original OCaml 4.14.1 supplies all three results. A private full large SML pilot
also matches its original; canonical smoke/normal checks and configurations
are recorded separately. Further edge cases include empty input, case changes,
adjacent substitutions, an unterminated header and overlapping motifs.

### Validation

The 23-check target compares twelve original Str-library observations and five
full original program reports, plus the smoke fixture, bad-output rejection,
negative indices, literal/escaped pipe distinction, malformed classes and empty
replacement rejection. Library cases cover ordered alternatives, greediness,
backtracking, line/end anchors, negated sets, overlapping counts and ASCII
case folding. The original executable and its generator remain correctness
references. Measurements compare identical SML sources across SML compilers.

### Literature and diagnostic interpretation

[The Benchmarks Game description](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/regexredux.html)
defines the motif/replacement sequence and notes that regex libraries can use
different algorithms. [The OCaml 4.14 Str manual](https://ocaml.org/manual/4.14/api/Str.html)
documents the matching, anchors and replacement interface used for the adapter;
actual original-library observations establish the selected edge cases.

Investigate regex compilation, literal/class scanning, greedy backtracking,
intermediate string allocation and buffered input. These are source-based
questions. Exact original report agreement establishes the selected results;
current timings or allocations alone do not attribute differences to a regex
engine, library implementation or compiler transformation.
