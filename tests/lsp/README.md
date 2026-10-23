# Language-server acceptance and measurements

The roadmap is `docs/plans/language-server.md`. Tests and measurement
policy are written in Standard ML; the executable wrappers only launch
their bytecode. Run commands from the worktree root so fixture paths have
their documented meaning.

## Real compiler-project replay

`make bin/rune-lsp-project-replay.rbc` builds an independent stdio replay
for opening `src/main/rune-main.sml` in the complete `rune.build` project.
It explicitly supplies the source/library root and target, then sends the
diagnostic/hover/symbol/link burst before waiting for any response. Latencies
start at dispatch and include queue time. Any failed response fails the run.

```
bin/runevm bin/rune-lsp-project-replay.rbc /absolute/VM /absolute/runelsp.rbc \
  /absolute/rune-source /new/results/replay.json
```

The unchanged installed `f4ee51368` release fails this replay at its existing
256 MiB heap, 768 MiB address-space and 30-second job limits. The ledger is
`baseline/2026-10-24-rune-project.json`; raw logs, the installed VSIX and
source hashes are retained outside Git under `rune-benchmark-results/lsp`.
Small protocol examples alone do not establish project-editing acceptance.

Set `RUNE_LSP_PROFILE=/absolute/new/phases.jsonl` when launching the server
to capture opt-in phase observations from its private worker. Each JSON line
records the job, phase, unit, elapsed microseconds, cumulative allocated bytes,
last collected live bytes, heap capacity, collections and work counts. This
file is separate from protocol stdout. Keep profiles outside the workspace's
source tree; source paths are included, but source contents are not.
These counters include observer overhead; `live` is the collector's last
measurement, not a collection forced at each phase. Record process RSS with
an independent process measurement alongside these samples.

`RUNE_LSP_REPLAY_CYCLES=100` extends the real-project replay with alternating
leaf revisions, diagnostics and hover. Every tenth revision contains an
explicit `int`/`bool` mismatch; the next revision repairs it. The replay also
checks project navigation and completion. These are semantic/retention
acceptance runs; record competing compiler or host-suite load before using
their latencies as performance evidence.

## Document and workspace foundations (M3)

`make test-lsp` checks document lifetimes, atomic sequential edits,
synchronization recovery, resource limits, save payloads, independent
randomized edits, project discovery/context selection, scoped requests,
watcher balance and stdio transcripts. Portable position/URI cases are
also `tests/lib/lsp/position.sml` and `uri.sml`; native host entries run
the same sources.

The independent edit oracle treats UTF-8 scalar/newline atoms as a list;
it computes positions and expected text without using the index under
test. Tests distinguish scalar boundaries from grapheme clusters and
exercise BOMs, mixed line endings, supplementary characters, parent arcs,
Windows drives/UNC and percent-encoded WTF-8 filename bytes.

The paired position-index benchmark includes text replacement and index
work, with hashes/oracles outside timing:

```
make bin/rune-lsp-documents-bench.rbc
bin/runevm --jit=off bin/rune-lsp-documents-bench.rbc \
  --out /tmp/runelsp-document-results --repetitions 20 --warmup 3 \
  --machine "record CPU, operating system and available processors"
```

Use a fresh output directory. `samples.jsonl` contains one cold-index
sample per named fixture and paired full-index/incremental-edit samples;
warmups are excluded and pair order alternates. `complete.json` is written
only after validation succeeds and records fixture hashes, compiler/VM
identities, commands' repetition settings and machine description. These
measure document indexing, not incremental parsing or resident semantics.
The [M3 ledger](baseline/2026-10-22-documents.json) records the initial Linux
distribution, source/observer hashes and archived raw samples.

## Separate editor syntax (M4)

```
make test-lsp-syntax
make bin/rune-lsp-syntax-bench.rbc
bin/runevm --jit=off --heap-limit 536870912 bin/rune-lsp-syntax-bench.rbc \
  --out /tmp/runelsp-syntax-results --repetitions 20 --warmup 3 \
  --machine "record CPU, operating system and available processors"
```

The public `RuneCompiler.Syntax` tests also run on native compiler hosts.
The private differential suite compares full constructor/scalar/span
structure with fresh batch parsing, using accepted and rejected language
fixtures, frontend sources, deletions and randomized edit/undo sequences.
It checks fixities, lossless bytes and topdec boundaries separately.

The [initial syntax ledger](baseline/2026-10-22-syntax-initial.json) includes
lexing, compiler ownership setup and complete AST conversion. Larger
fixtures do not pass the sharing threshold: keep the parser separate.
These EOF-newline samples are an initial comparison, not representative
edit-trace or release performance acceptance.

## Analysis and worker foundations (M5)

`make test-lsp-analysis` runs the public snapshot/checkpoint, cancellation,
binding, generative-type, library and project-scope checks in the
interpreter and JIT. It also compares inferred types with fresh batch
compiler queries. The same public tests run on all native SML hosts.
[The analysis contract](../../docs/compiler-analysis.md) describes current
recovery limits and the source/context ownership rules.

`make test-lsp-worker` tests private binary framing, arbitrary native
filename bytes, backpressure, independent input readiness, process-group
cancellation and truncated output. Its process test can also run under
the native Windows VM:

```
bin/runevm.exe bin/rune-lsp-worker-process-tests.rbc \
  bin/runevm.exe bin/rune-lsp-worker-echo.rbc
```

The worker transport is private and reuses Content-Length framing. LSP
messages remain UTF-8 JSON. Internal byte strings preserve WTF-8 paths
and malformed disk-source bytes until the compiler reports them.

## Semantic stdio transcripts (M5-M8)

`make test-lsp` also runs the production server through an independent
interactive client. The semantic cases cover push/pull/workspace reports,
refresh and partial progress, cancellation, stale requests, native project
paths, navigation, symbols and lexical completion/resolve. Compiler scope
tests cover shadowing, hidden members, whitespace, unfinished local
expressions, typed record labels, named call arguments and queries after
closing their original contexts or deleting the original library.
Feature transcripts also verify UTF-16 signature labels, expanded invocation
snippets, inline constructor patterns, captured documentation, namespace
filtering and legacy-client fallback.

After building the bytecode, run the same production transcripts natively
on Windows from this directory:

```
bin/runevm.exe bin/rune-lsp-semantic-tests.rbc bin/runevm.exe bin/runelsp.rbc
```

Keep the server payload beside its VM: worker startup locates the VM in
the payload directory. Passing tests record only this feature cohort;
they do not stand in for full roadmap or performance acceptance.

## Frontend baseline (M1)

```
make lsp-bench
make test-lsp-bench
bin/rune-lsp-bench --out tests/out/lsp-baseline --repetitions 20 --warmup 3
bin/rune-lsp-bench --out tests/out/lsp-with-prototype --service bin/rune --repetitions 20 --warmup 3
```

`RUNE=bin/rune-mlton` selects the faster native compiler while developing
the harness. The harness itself runs on Rune's VM. Every output directory
must be new: existing evidence is never replaced. A failure returns a
nonzero status, preserves diagnostic artifacts and publishes no successful
measurement summary. `--service` uses the existing newline JSON-RPC
compiler prototype, not an LSP server; it owns a private unit-cache path
and verifies actual diagnostics and `answer : int` hover responses.
Use the self-hosted `bin/rune` for that prototype: the current native-host
entry points call the batch driver and do not implement `--serve`.

`fixtures/manifest.json` has schema version 1. Each fixture specifies its
name, source mode and expected parser acceptance, and either ordered files
(relative to the manifest) or a generated declaration count. Optional
edits specify half-open byte ranges against the preceding decoded revision,
replacement text and expected acceptance. This is a parser/edit baseline;
acceptance does not assert that an unbound source fragment typechecks.

Results contain:

* `fixtures.jsonl`: source SHA-256, decoded byte counts, verdicts, token
  hashes, declaration counts and a supplementary AST debugging hash.
  That debug hash is not a structural AST equivalence proof.
* `samples.jsonl`: per-source edit, lex and parse timings, with revision,
  measured repetition, CPU time and allocation-counter deltas. Warmup and
  source/hash verification are outside the timed work. Counter deltas
  include the measurement observer's small allocation cost.
* `summary.json`: nearest-rank p50/p95/p99 for each source and phase.
  Twenty repetitions provide an initial distribution; the parser-sharing
  gate also requires enough trace edits and confidence intervals.
* `metadata.json`: compiler version/identity, harness and VM hashes,
  platform, processor count, VM options and heap observations.
* `retention.jsonl`: a separate replay pass with full collections before
  and after each cycle. It records live/heap bytes without inserting
  forced collections into the headline timings. `--retention-cycles N`
  controls this pass (three by default).
* With `--service`, `prototype-service.jsonl` records startup/initialize,
  the first check using a private cache, repeated diagnostics/hover, and
  waited-process resource usage. Each measured process has its own cache,
  configured warmup cycles and one measured diagnostics/hover pair; process
  repetition IDs keep these independent runs paired. Server stderr is
  retained in the corresponding `prototype-N` directory.

The fixtures include malformed input, comments/string gaps, ordered fixity,
edit/undo traces, 10,000 generated declarations and the compiler frontend.
The arithmetic oracle independently interprets infix trees and catches a
planted reuse of the old fixity environment. Command-level tests reject a
planted wrong verdict, verify phase/warmup counts and protect existing
result directories. These establish the baseline harness; incremental
syntax and compiler-session correctness have their own later milestones.

Retain raw measurements under `tests/out` or the benchmark-results archive,
with compact versioned ledgers identifying commands, fixtures, machine and
source revisions. Measurements of unavailable future features remain
unrecorded until those features exist. A Linux baseline does not establish
native Windows behavior or the less-than-10% parser-sharing condition.

The initial Linux measurements, source hashes, observer hashes and proposed
release budgets are in [the initial ledger](baseline/2026-10-22-initial.json).

## Protocol acceptance (M2)

```
make test-lsp-protocol
make check-lsp-protocol
```

The wire client in `protocol-tests.sml` assembles and reads its own frames,
independently of the production framing/envelope codecs. It tests minimal
and modern capabilities, progress, lifecycle, IDs across the full signed
32-bit range, malformed requests/notifications/responses, size limits,
truncation, tracing and interactive stdio without EOF. Portable value,
capability and request-ownership cases also run as `tests/lib/lsp` on the
native hosts. Both protocol acceptance and baseline-producer acceptance
are registered in the repository's normal check tier.

The semantic transcripts cover inferred pattern type hints, negotiated tooltip
resolution, all position encodings, visible ranges, stale/forged metadata,
refresh and explicit response limits. The large hint fixture is checked before
testing its limit; it is never executed. `worker-analysis-tests.sml` terminates
and starts an actual worker, checks that view IDs cannot repeat, and rejects an
old view reference in the new process. The original worker fails both restart
assertions. `service-tests.sml` also verifies that malformed hint metadata does
not retain a completed request ID.

The compiler-owned frozen queries run on the supported hosts with:

```
bin/rune-test run -j 2 'lib-hosts/*/compiler.analysis'
```

For native Windows transcripts, stage each width's VM beside `runelsp.rbc`
under the filename `runevm.exe`, and launch the client with that VM and server
path. The server derives its worker VM from this directory; a 32-bit front end
alone does not establish 32-bit worker coverage. Keep server, worker and client
payloads frozen while each native cohort runs.

Build-link transcripts compare each resolved file URI's native file ID with the
actual source/build/library/directory target. They cover Unicode and spaces,
unknown variables, tooltip negotiation, missing targets, modified ranges,
source/context changes and reordered JSON objects. Separate fixtures exceed the
link count and byte limits; an ordinary SML string never creates a guessed link.

The [framing ledger](baseline/2026-10-22-framing.json) records paired
comparisons with the earlier decoder in the same VM. Its archive contains
the original signature/implementation with only their names changed, the
observer bytecode and VM, and all raw samples. To rerun from that archive:

```
bin/rune --library jsonrpc PATH/old-framing.sml tests/lsp/framing-performance.sml -o tests/out/framing-performance.rbc
bin/runevm tests/out/framing-performance.rbc
```

The observer alternates candidate order, performs collection outside timed
work, and verifies decoded message bytes after each measurement. Its byte,
64-byte and 4096-byte chunks exercise the actual framing path; these are
not compiler/query or parser-sharing measurements.

Separate repository test-runner invocations share a history file by
default. Run those invocations serially, or supply different `--history`
paths; simultaneous default-history writes can race on its temporary
file. The standalone LSP transcript programs do not write that history.
