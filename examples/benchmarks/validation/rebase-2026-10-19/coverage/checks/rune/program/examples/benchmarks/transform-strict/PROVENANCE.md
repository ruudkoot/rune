# transform-strict provenance

### Algorithm and workload

Parse functional dataflow programs, remove aliases/redundant definitions,
retain used stream bindings, label nodes, inline eligible functions and
perform the original stream/state rewrites. Render six successive versions
as source/script text and sum their output lengths. The generated programs,
include paths and shell commands are output data; never execute them.

Preserve the v/v0/v1/v3/v5/v6 pipeline and its exact ordering. This is a
compiler/symbolic workload even where the input describes FFT, wave or other
numerical networks; those target networks are not evaluated.

### History, names, inputs and notices

[nofib Hartel transform](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/hartel/transform)
is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. The generated module states no separate individual
program/data author or permission notice. Preserve its complete text,
Makefile, original FAST/NORM/SLOW outputs and parent Fast2haskell shim.
References to a person's home-directory paths do not establish authorship
or an external runtime dependency.

The original module contains eleven embedded examples. The selected cyclic
stream is FFT, Fibonacci, Fibonacci sum, flip-flop, gamma, Hamming, set/reset
and wave4, in that exact order. Simple, tailtest and wavestream remain
complete source/semantic controls. They are additional input examples for
this algorithm, not separate imported algorithms or default cycle entries.
The -lazy/-strict suffixes identify meaningful finite-data policies.

### Translation, demand and representation

Keep typed definition, where and expression nodes, character-list names,
source comparisons, merge/quicksorts, single-occurrence removal, ordered
substitution, reachability approximation and first eligible inlining.
Retain label comparisons and short-circuit later fields after an earlier
comparison differs. Inline only matching-arity no-where functions, remove the
current definition from candidates and do not recursively inline a newly
substituted body in the same pass.

Preserve the source variable analysis that ignores Cons/Maps state fields.
Labelling increments by two, labels a stream before its Cons state and labels
Maps arguments before its state. Memoized paired results share transformed
values and counters without forcing an unused numeric projection.

Preserve t5's four scans, reversed prefix accumulators, restart behavior and
remembered label-pair termination guard. Do not insert helpful reversals or
sorts. T6 partitions the used program but appends its new output/state
definitions to the original program. Source stopping and selection rules
remain unchanged.

Data fields and finite list spines use the common memoized/strict policy;
lexical, parser-result, paired-labelling and cyclic-program control remains
memoized. The cyclic input is tied explicitly before forcing it, and a finite
take bounds the selected work. Conversion/join callbacks remain delayed in
the lazy parser. Typed cached grammar closures retain source sharing.

The source parser chooses the first accepted program prefix and discards
remaining tokens; do not add an EOF requirement. Preserve its first-result
cuts, pragma/comment rules, and numeric-token rule that treats 1+2 as one
raw numeric spelling. This syntax pass does not evaluate numeric literals.

The original consumer forces report list spines to determine length, rather
than validating every character. Keep character cells separate from spines:
length alone skips unused characters. The source indentation routine does
inspect character contents to match newlines, and retains that demand.
Complete text/AST validation is a separate semantic target, not extra timed
character forcing.

The shared shim's miraseq and force are no-ops. Preserve lazy numeric
accumulation instead of inferring strictness from the helper's name.
Strict variants materialize finite data while retaining bounded control.

Embed exact original input strings in portable SML source. Each benchmark
invocation creates eight shared, delayed prepared roots and cycles over them.
Repeated in-process invocations rebuild those roots; grammar/literal caches
belong to the functor instance. Record that adapter scope instead of claiming
identical cross-language CAF behavior in every measurement mode.

Fixed character-list literals are created once per functor instance, matching
source immutable literal sharing. An offline token-aware transcription step
lifts 55 distinct literals used at 83 sites; runtime contains ordinary SML
bindings and no lookup interpreter or opaque barrier. Preserve compiled-input
specialization opportunities without claiming equal compiler transformations.

### Profiles and correctness checks

| Profile | Programs selected from the eight-example cycle |
|---|---:|
| Smoke | 8 |
| Normal | 3000 |
| Large | 15000 |

Normal and large preserve NORM/SLOW counts. Smoke explicitly reduces source
FAST 300 to one complete cycle. Every selected report length is checked
against the reviewed original length, and the total is checked independently.
Return the original integer total without its newline through the common
driver. Smoke totals 28275, normal 10603125 and large 53015625.

All embedded text and emitted profiles are ASCII. Numeric literals remain
raw syntax strings; labels, lengths, namespace counters and totals fit signed
31-bit integers. The driver bounds counts to 0..20000 and rejects invalid
arguments. No floating-point approximation or arbitrary precision shortcut
replaces the compiler algorithm.

Read-only original observers record all eleven complete token streams,
parsed/prepared trees, transformation states and reports. Both policies must
match every full state and all report bytes. Original FAST/NORM/SLOW executions
match their supplied fixtures. Independent structural checks cover 88 original
ASTs and 5072 nodes, including constructor types/arity, ASCII names and bounded
odd positive labels. Independent cycle arithmetic agrees with all three
golden outputs; it is not a proof of dataflow-network equivalence.

Direct controls cover callback sharing/demand, first-result cuts, prefix
parsing, lexer quirks, self-inlining exclusion, source variable analysis,
comparison short circuits, character/indentation demand, zero work, cycle
wrap and deliberate wrong-length rejection. Full large SML runs are recorded
only when actually executed, separately from individual case/state coverage.

### Compiler/runtime questions and evidence limits

Investigate parser backtracking, symbolic tree copying, sort/comparison order,
repeated rewrites, name/label generation, character-list sharing, delayed
numeric accumulators, finite materialization and retained prepared inputs.
These are source-based hypotheses. Same-source SML compiler/engine counts
and measurements must identify their exact mode/configuration; original
Haskell is a correctness reference rather than an identical-cost baseline.

### Literature and review scope

The previously reviewed Hartel and Langendoen (1993) translation account
supplies collection context. Pinned source establishes this parser, compiler
pipeline and demand behavior. No paper on the numerical target networks is
claimed as a derivation of the executed transformation code. Original full
observations and independent structural/cycle checks establish the recorded
scope; no general transformation-correctness proof or measured compiler
mechanism is implied.
