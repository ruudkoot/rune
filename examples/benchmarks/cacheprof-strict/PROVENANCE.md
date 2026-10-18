# cacheprof-strict provenance

### Algorithm and workload

Annotate textual x86 assembly with instruction counters and calls to a cache
profiler. Preserve source preparsing, AT&T lexical/operand parsing, repeat
and leave expansion, basic-block grouping, operand effects, source-location
cost centres, generated descriptors/calls, peephole cleanup and debug-line
removal. Assembly and hook files are text input/output; this workload never
assembles or executes them and needs no FFI facility.

### History, source variants and notices

[nofib Cacheprof](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/cacheprof)
is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. Main, Arch_x86 and Generics credit Julian Seward,
copyright 1999, with GPL version two or later notices. Preserve both source
collections and notices. The pinned directories refer to LICENSE but omit
that file; supply an unmodified GPL-2 text as COPYING from the installed
Debian common-license text. Translated derivative modules retain the full
original notice. Hook assembly has no separate notice in its header.

The GC Main emits one annotated input followed by hook text. The real Main
opens a hook file and fully forces annotated output in 200 repetitions,
printing nothing. These are materially different consumers of shared code.
Use cacheprof-lazy/strict for the GC source and cacheprof-nofib-lazy/strict
for the colliding real source, retaining both original modules and all
provenance. Finite stage streams and generated groups follow the named policy.

Assembly fixtures identify heimdall.c and historical gcc output. No separate
dataset author/license notice is stated in the scanned assembly; retain full
pinned files and their identities without assigning program credits to the
underlying C input. The supplied FAST/normal/SLOW inputs contain 76/600/3040
lines; cacheprof.full contains 13708.

### Translation, evaluation and numeric decisions

Use tagged SML datatypes for source instructions, operands, annotations and
location metadata. Generate all 206 opcode constructors/effect-table entries
from the pinned source and check them against original Haskell observations.
Preserve the explicit 67-entry nonJumpy list; do not replace it with a broader
derived jump classification. Parser combinators, ordered alternatives and
instruction simplification remain the source algorithms.

Use memoized finite list spines/heads and deferred generated groups in the lazy
policy; the strict policy materializes them. Parsed instruction descriptors
are strict metadata, corresponding to the original forceLine boundary. Rollup
descriptor lists/indices use explicit finite strict bridges; debug text follows
the policy. Source ASCII character lists become SML strings at input and
per-output-line boundaries. Record these representation, library and temporary
allocation differences rather than claiming identical Haskell costs.

Preserve source quirks: generated repeat-label Pseudo numbers are the label
counter; quoted commas in stabs arguments become underscores; file/function
guessing, canonical-name order, arbitrary nonJumpy membership and the counter
peephole predicate remain unchanged. Level-zero prefix demand can skip a bad
later instruction; level two's global cost-centre guard must inspect it.
Independent original prefix observations confirm both cases.

No floating-point or arbitrary-precision kernel arithmetic is needed.
Source indices, line numbers, counter increments, 28-byte descriptor offsets
and selected aggregate byte counts fit signed 31-bit integers. The generated
64-bit counter operations are assembly text, not SML machine arithmetic.

### Inputs, profiles and complete validation

| Consumer | Smoke | Normal | Large |
|---|---|---|---|
| GC/raw | one FAST 76-line input | one normal 600-line input | one full 13708-line input |
| Real/forced | one FAST input | 200 normal inputs | 200 SLOW 3040-line inputs |

FAST input is borrowed explicitly from the real collection for GC smoke.
GC normal is byte-identical to the real normal input. Real normal/large retain
the source 200 repetitions; smoke reduces that count to one. Per-profile
input-origins tables identify original paths and SHA-256 values.

The pinned GC stdout fixture belongs to the full input reservoir, while its
current default stdin is a 600-line prefix. The unmodified GC executable fed
cacheprof.full reproduces all 1671273 fixture bytes exactly. Retain that
complete input/fixture pairing for GC large and obtain reviewed normal output
from the unmodified original. Do not treat the mismatch as a compiler failure
or overwrite the historical fixture.

Check every annotated output byte online. Raw GC additionally emits/checks
all hook text; the real consumer checks only its annotated output, retaining
per-iteration hook open/close without reading unused contents. SML closes
those handles deterministically, replacing the Haskell lazy-handle lifetime.
Preload source/reference strings once and retain the source 9999999-character
input cap; all selected fixtures are smaller. Source take-list allocation is
replaced by the string adapter. Return checked byte/repetition counts instead
of raw terminal output. The extra reference comparisons are explicit work.

Original full outputs cover all three supplied input sizes and the complete
reservoir. Additional original cases cover 206 opcodes, applicable operand
arities, indirect forms, three profiling levels, repeat expansion, location
metadata, syntax and rejected inputs. Synthetic parser/effect cases exercise
the source grammar; they are not claims of executable x86 instruction validity.
Demand, memoization, strict materialization, zero-work and deliberately
corrupted/truncated-output controls supplement complete original fixtures.

### Compiler/runtime behavior and validation scope

Investigate persistent stage spines, shared consumers, descriptor rollup,
closure specialization, string/list boundaries and strict allocation lifetimes.
These are source-based hypotheses; counter agreement does not attribute
individual performance costs.

Separate the bounded 822-assertion semantic target from four explicit full-
reservoir checks. An initial mixed target exhausted ML Kit's 1 GiB limit
during strict full-result materialization. Retain that failed attempt.
The isolated large target passes ML Kit with the declared 8 GiB profile
limit under the protective process-tree guard. Kernel and expected bytes are
unchanged. The large probe does not establish every large profile/host run.

Smoke/normal engine and host results, count scopes and full repository
acceptance are recorded in the validation ledger. Native O0/O2 labels repeat
host-default options. Deterministic input references and correct results are
required before accepting measurements.

### Literature and evidence scope

[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides application-suite context at the survey scope already recorded.
Seward's individual source notices and stage comments establish this tool's
history and transformation design. No external cache-profiling paper is
claimed as a reviewed derivation. Original executable/fixture and exhaustive
source-table observations support correctness; compiler/runtime explanations
remain hypotheses until measured separately.
