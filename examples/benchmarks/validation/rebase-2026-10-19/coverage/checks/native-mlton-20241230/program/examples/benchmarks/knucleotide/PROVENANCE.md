# knucleotide provenance

## Algorithm and workload

Extract the FASTA sequence whose header begins with >THREE, uppercase it, and
count overlapping nucleotide substrings. For each length, clear a chained hash
table, reuse a mutable lookup key, copy the key only on insertion, and increment
a reference on a hit. Emit sorted one-/two-base frequencies and counts for the
five source queries of lengths 3, 4, 6, 12 and 18. Preserve the inclusive final
window and the original descending-frequency/ascending-key ordering.

## History, authorship and aliases

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/benchmarksgame/knucleotide.ml credits Troestler Christophe and Mauricio
Fernandez, with Computer Language Benchmarks Game ancestry. Preserve that file,
Dune, directory README, Revised BSD notice and aggregate Unlicense. OCaml 4.14.1
library sources are separately pinned at 99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93;
the installed hashtbl.ml and buffer.ml match those exact source bytes. Their
Xavier Leroy/INRIA copyrights, LGPL 2.1 notice and linking exception are retained.
The replacement buffer/table support follows those algorithms; the corresponding
notice also appears in the SML source.

## Differences between known variants

The separately inventoried knucleotide3 packs nucleotide values into integers,
uses width-dependent key thresholds and retains its tables across query lengths.
Its loop also omits the last window. These are material differences; do not
replace the present byte-key/clear-per-length implementation or its expected
frequencies with that version. Original full outputs and independent replays of
both variants document the differences. knucleotide3 is not claimed imported here.

## Portable translation and adaptations

SML97 CharArray keys replace OCaml Bytes; integer references retain mutable counts.
A self-contained chained table starts with 262144 buckets, uses the source
polynomial hash h*5+byte, inserts at the head, and doubles above two entries per
bucket. Rehashing preserves chain order with mutable links and tail arrays.
Word64 retains the source's 63-bit hash arithmetic without host-Int-width
assumptions; bucket indices/counts fit every selected SML host's Int. SML's
record/reference and generic array layouts may add indirections or initialization.
Lookup returns an SML option instead of raising OCaml Not_found on a miss.
Counts still perform exactly one lookup and copy only newly inserted keys;
option construction/branching replaces the source exception boundary and is an
explicit library-call cost difference, rather than a measured optimization claim.

The input buffer starts at 1000, doubles as required, retains its existing bytes,
and makes the final sequence copy. ASCII uppercasing and terminal-LF removal
preserve source input semantics. The first-data-line catch-all and comment skip
remain, as do rejection of an empty subsequent line and missing THREE header.
Closing the file on return/error supports repeated invocation. All mutable
sequence/table state moves from process initialization into Benchmark.run,
restoring fresh-process semantics on every repetition and avoiding file I/O
while native hosts export their entry points.

SML97 has no standard sort, so portable merge sort replaces List.sort. The exact
comparison, binary64 operation association and fixed three-decimal formatting
remain; sort implementation/allocation is an explicit library adaptation.
A callback replaces stdout and the BinIO checker consumes every output byte plus
EOF before returning its byte count. Input loading, table allocation, formatting
and reference I/O/checking are measured work. No precomputed frequency replaces
execution of any count pass.

## Compiler/runtime behavior to investigate

Byte-key copying, collision chains, mutable counters, clearing cost, table growth,
string/buffer retention, boxing, Word64 arithmetic and sorting/formatting are
source-based performance questions until supported by inspection or measurement.
Standard reports compare identical SML; OCaml supplies correctness references.
No parallelism, effect handlers or FFI are required.

## Inputs, checks and references

Smoke/normal/large reuse pinned fasta3 inputs with n=1000/50000/500000, seed 42,
width 60 and the embedded ALU/probability tables. THREE contains 5000/250000/2500000
bases. Source Dune uses n=25000000 and also generates n=5000000; those complete
revcomp/nucleotide defaults are not claimed executed here. Large is an explicit
reduced scaling input. No separately acquired dataset or dataset notice is added.

Complete original outputs agree with an independent dictionary-based substring
counter for every selected input, including the large reference. Original edge
fixtures cover case conversion, prefix header matching, initial comments, record
termination, short input, absent terminal LF, initial empty lines and unusual
characters. Tests also cover rejected malformed inputs, deliberately wrong/
truncated/extra references, per-length clearing, and 256 independent four-mer
counts through forced collisions and multiple table resizes. Large SML execution
is claimed only where separately recorded. The retained source headers and suite
measurement survey provide the history/methodology; no historical timing claim
is transferred to this translation.
