# Language-server acceptance and measurements

The roadmap is `docs/plans/language-server.md`. Tests and measurement
policy are written in Standard ML; the executable wrappers only launch
their bytecode. Run commands from the worktree root so fixture paths have
their documented meaning.

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
