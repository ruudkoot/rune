# knucleotide3-64 provenance

Selected key threshold: 31; fixed 64-bit source-bit representation.

## Algorithm and workload

Extract the THREE record from FASTA, encode A/T/C/G as 0/1/2/3, and count packed
keys in persistent-across-pass chained hash tables. Print sorted one-/two-base
frequencies and the five original query counts. Preserve the loop's omitted last
window and the absence of clearing between lengths: leading-zero keys of different
lengths can alias. These are source behavior, not errors for this port to fix.
The driver validates every output byte and EOF before reporting its byte count.

## History, upstream revision and notices

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/benchmarksgame/knucleotide3.ml. Its header credits Troestler Christophe,
Mauricio Fernandez, Fabrice Le Fessant, Roman Kashitsyn and KC Sivaramakrishnan,
whose change removes parallelization. Retain that header, directory Revised BSD
notice, aggregate Unlicense, README, Dune and fasta3 input-generator source.

Portable buffer/table support follows OCaml 4.14.1, pinned at
99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93. Selected hashtbl.ml/buffer.ml bytes match
the installed sources. Retain the Xavier Leroy/INRIA copyrights, LGPL 2.1 notice
and linking exception, including the notice in the SML adaptation. Generated
FASTA carries the same fasta3 provenance as the other nucleotide imports; no
unattributed external dataset is added.

## Numeric variants and source differences

knucleotide3-64 preserves threshold 31: all current query lengths use single packed
keys. knucleotide3-32 preserves threshold 15: the 18-base query uses two packed
components in a separate table. Both tables are allocated in both variants,
including an unused second table in the64 variant. Pair hashing uses only the
first component, with equality comparing both. These materially different key/
table representations merit separate names. Both run identically on all SML
host widths using explicit Word64 rather than native Int width selection.

The byte-key knucleotide benchmark clears its table per length and counts the
last window. It is a separate algorithm/representation variant; its fixtures
are not interchangeable with the packed counter. Do not consolidate them.

## Portable SML97 translation

Multiply/add and shifts use Word64. Source32 components need at most 30 significant
bits; 64-bit source packed keys need at most 62, with 36 used by the largest current
query. No wrap occurs in the selected positive domain. Explicit Small/Large
constructors select the key representation; SML tagging/Word64 boxing may add
indirections compared with native OCaml ints/pairs. Counts, bucket indices and
profile sizes fit signed 31-bit Int. This is not a claim that host-native integer
arithmetic has the same allocation cost.

A mutable chained table keeps source initial capacity 262144, identity/first-key
hashes, head insertion and doubling above two entries per bucket. Transfer
preserves collision-chain order. Lookup uses an option instead of Not_found;
that library boundary and its allocation/branch cost are explicit adaptations.
The table is never cleared between the seven count passes. Both table instances
and sequence buffers are recreated per Benchmark.run, preventing a repeated
in-process invocation from accumulating results from its previous invocation.

The portable input buffer begins at 1000 and doubles as needed, following the
same copied-buffer algorithm used by the existing byte-key port. This replaces
the source's fixed 130000000-byte initial reservation for its much larger default
input; record the changed allocation footprint when comparing profiles. Per-line
encoding preserves ASCII tab values, including the source's default0 for unknown
bytes. Initial comment/catch-all handling, prefix header selection, later empty-
line failure, terminal-LF removal and stopping at the next record remain.

Portable merge sort replaces OCaml List.sort while preserving descending
binary64 frequencies and lexical ties. Binary64 operation association and three-
decimal formatting remain. The original hardcoded filename becomes an argument;
complete output checking replaces stdout and is included measured work. No FFI,
effect handler, parallel feature or prerequisite runtime change is introduced.

## Inputs, profiles and diagnostic questions

Smoke/normal/large reuse the pinned fasta3 inputs with n=1000/50000/500000,
seed 42 and width 60. THREE contains 5000/250000/2500000 bases. The original Dune
n=25000000 and auxiliary n=5000000 remain documented, not claimed executed here.
Large is an explicitly reduced scaling input. Input generation is available in
the suite's portable SML fasta3 implementation, with exact complete files pinned.
Default profile limits apply; original outputs for all selected sizes are retained.

Source-based questions concern packed-key arithmetic, width-dependent pair
allocation, repeated packing, cumulative aliasing, identity-hash collisions,
retained tables, bucket growth, buffer copying and string formatting. They remain
hypotheses until supported by inspection or measurements. Standard reports use
identical SML; OCaml supplies correctness references.

## Reference evidence and validation

The unmodified64-bit OCaml program agrees with an independent packed-key model on
all complete smoke/normal/large outputs. A separate observer changes only the
threshold to 15 and agrees with the independent two-table/pair model. It does not
constitute execution by a 32-bit OCaml compiler. Managed32-bit SML host results are
recorded separately. Model statistics retain every pass's entries and total counts.

Original complete edge fixtures cover case conversion, THREE-prefix matching,
initial comments, next-record termination, no final LF, short/empty input and
unknown bytes. The original library observer records 512 deliberately colliding
keys through repeated resize, exact fold traversal and every smoke pass's table
statistics. Tests cover omitted-window bounds, cumulative leading-zero aliases,
31-/15-digit representations, pair hashing, both full output variants, and
wrong/truncated/extra output rejection. Large SML and additional host validation
are claimed only where recorded. Retained program/library sources explain the
exact algorithm; the suite's measurement survey supplies methodological context.
