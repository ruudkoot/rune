# mkhprog-strict provenance

Finite text evaluation: strict.

## Algorithm and workload

Generate a Haskell command-line parser skeleton from flag/type specifications.
Validate flags and duplicates, build default arguments, usage text and data
declarations, and emit parser clauses and auxiliary readers through a
continuation-passing writer. Consume each emitted block separately, as upstream.

## History, authorship, revision and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/mkhprog.
The literate title and author declaration identify N. D. North, National
Physical Laboratory, version 2.4 dated June 23, 1992. Preserve Crown Copyright
1992 on the translation, templates and driver, and retain Main.lhs, the
mkhprog.1 manual and bundled input. No separate redistribution grant is stated
in the individual source; do not invent one.

The manual identifies an earlier C mkprog with related functionality and
manual text, while explicitly calling the implementation different. Its source
is not supplied, so no duplicate implementation is claimed. Keep the established mkhprog name with lazy/strict
suffixes. The input specification comes from the pinned nofib file; its
individual author is unstated.

The generated program is a historical skeleton: System imports, deriving ()
and unresolved ?? defaults remain unchanged. Validation concerns generated
text; it does not require compiling or modernizing that skeleton.

## Portable translation and evaluation

Retain continuation composition, environment lookup, flag order, case-sensitive
duplicate checks and per-block emission. The output is a persistent character
list whose spine uses the selected memoized-lazy or eager finite policy.
String append and concatenation preserve the source expression order.
Four fixed auxiliary templates remain shared.

Literal type comparisons inspect characters only until a mismatch, matching
the source list patterns. They do not flatten the whole type before choosing
a default or reader. The lazy policy leaves unused later text unforced; the
strict policy materializes finite text during construction. Both policies
propagate an output consumer's early stop without continuing emission.
Callbacks preserve the source continuation order and output channels.

Normalize input once using the source words/unlines boundary, then rebuild
the parser/generator work for each repetition. The original GHC allocation
diagnostics grow from about 3.06 MB at one repetition to 10.81 GB at 3800 and
51.22 GB at 18000. These observations support repeated work; the port does
not memoize a complete generated program or its hashes across iterations.
Allocation diagnostics are separate from performance timing claims.

Selected input characters are ASCII. Input tokenization uses portable SML
strings; generated text retains explicit character-list structure. Integer
argument indices and profile counters fit signed 31-bit integers. Explicit
Word64 arithmetic supplies the original GHC 64-bit Int hash wrapping on every
host, regardless of default int size.

The original stdout consumer hashes each writeln/newline block independently
and discards that hash. The driver compares every block with a reviewed
original hash in order, enforces the block count and returns a stable
repetitions:blocks:hexadecimal-sum report. Its final sum wraps modulo 2^64.
It does not replace the source workload with one whole-program hash.

Timed profiles select hashed stdout. Auxiliary captures also retain named-file
channel selection, module changes and literate output. The benchmark driver
accepts the stdout profile contract; named-file content is observed through
the auxiliary capture adapter. Actual append-file timing is not selected.

## Profiles and correctness

| Profile | Source input | Repetitions | Blocks per iteration |
|---|---|---:|---:|
| Smoke | bundled 41-flag specification | 1 | 62 |
| Normal | bundled specification | NORM 3800 | 62 |
| Large | bundled specification | SLOW 18000 | 62 |

The fixed specification and its type/flag distribution remain unchanged.
Smoke reduces the original FAST repetition count of 350 to one. Normal and
large retain the source counts, with the suite's default resource limits.

Unmodified GHC runs at 1, 10, 350, 3800 and 18000 repetitions complete with
empty stdout. A consumer-only observer forces the original hash and records
the emitted text and channel. It changes no parser or generator algorithm.
Every full output, block hash and channel agrees for both SML policies across
nine cases: the default specification, auxiliary templates, empty input, integer,
Boolean/toggle, string, literate, inline module and named-file cases.
The default program has 62 blocks and 18794 characters.

Seven invalid specifications match the unmodified program's exact usage text.
Tests cover output ordering, missing/extra/corrupted block references, hash
width, normalization, repetitions, source reader choices, early output stop,
finite text demand, shared consumers and a mismatching type with an undefined
tail. Full output fixtures retain all original spaces and backslashes.

## Literature and diagnostic questions

The retained [literate source](../mkhprog-lazy/upstream/Main.lhs) is also North's
program description, with an annex explaining the continuation style and its
historical compiler context. The [manual](../mkhprog-lazy/upstream/mkhprog.1)
describes the flag interface. These program-specific documents were reviewed.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides suite context.

Investigate higher-order continuation specialization, character-list construction,
string sharing, append shape, literal pattern demand, closure lifetimes and
per-block hash consumption. Treat these source-based questions separately from
recorded allocation/count observations and eventual timing reports.
