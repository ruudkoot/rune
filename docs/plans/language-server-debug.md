# Installed language-server debugging

The installed `f4ee51368` package failed while editing
`src/main/rune-main.sml` in Rune's complete `rune.build` project. Work remains
isolated on `language-server-dist`; the original checkout is preserved.

## Milestones

| Milestone | Evidence and implementation |
|---|---|
| Reproduce the installed failure | `d3ce4b515`: independent concurrent diagnostic/hover/symbol/link replay; four heap failures in 77 seconds. |
| Measure the real project | `f2dcebccf`: opt-in phase/allocation observations; 231 checked units and 141,341 occurrences. |
| Bound resident analysis and supervision | `5c88e38e2`: immutable occurrence reuse, memoized type qualification, shared checks, failure backoff, bounded stderr and paired heap/process budgets. |
| Keep providers responsive and errors useful | `126ecec96`: document queries precede automatic workspace pulls; worker failures include request, context and last phase. |
| Complete the distribution presentation requests | `688cf5ddb`: gallery icon, categories, names/settings, and hidden helper build manifests. |
| Reuse frozen editor data | `e2688dc14`: bounded completion cache, exact-text position/token index reuse, optimizing worker JIT, and snapshot invalidation tests. |
| Verify interactive operation | Repeated edits, forced-collection retention measurements, native Windows, actual editor providers, cancellation and shutdown; receipts below. |
| Isolate editor tests | `8d2ce58e5`: Linux namespaces/private Xvfb and a minimized Windows Sandbox with scoped host cleanup; VS Code 1.143.1 checks on both platforms. |
| Deliver a versioned VSIX | Build from the clean acceptance commit; final artifact hashes, versions and run receipts are recorded in `build/lsp-debug/acceptance/final.json`. Publishing remains a user action. |

## Confirmed causes and fixes

The original worker exhausted its 256 MiB heap after elaboration, before
freezing the final occurrence list. The measured attempt allocated
11,716,565,160 bytes before that projection, with 256,656,760 last-collected
live bytes. Recursive mapping added a large stack at the limit. Separate
queued providers repeated the same failed full check and inherited stderr
forwarded the entire VM trace into VS Code's rotating output logs.

Projection now uses bounded stack space and reuses immutable lists for
validated unchanged unit keys. Qualified type names are memoized within one
unit's fixed environment. Exact source text/mode/path keys also reuse
prelude name sets instead of lexing every unchanged source on each check.

The worker uses the optimizing JIT, with a 512 MiB heap cap and a 1.5 GiB process cap. The 30-second
job deadline remains for document work; workspace sweeps have 30 seconds per
context and an overall allowance of 30 seconds for planning plus 30 seconds
per planned context. Count and source-byte retention budgets limit old
contexts and views. Concurrent providers share one check; cancellation of
one waiter preserves the others. An infrastructure failure completes all
waiters and suppresses further checks of the same failed revision and
workspace generation until an edit, dependency/configuration change,
close/reopen or restart.

Worker stderr is a private nonblocking pipe: a 4 KiB prefix is retained, a
64 KiB stream is terminated, and heap exhaustion is classified immediately.
Shutdown terminates and reaps all workers before replying. Automatic workspace
diagnostic pulls run in a separate worker from document checks and queries.
Cancellation replies immediately and grants 250 ms for acknowledgement.

An unconfigured checkout workspace exposed another retention path: the
workspace diagnostic/symbol collector kept a view for every analyzed context,
outside the resident cache's eviction budget. A focused replay of the installed
`2a11e26ce` reached the 512 MiB cap at `compiler/backend/lower.sml` while checking
`runelsp.build`. Workspace requests now group sources by context and collect
their JSON results before checking the next context. Reports preserve source
ordinals and URI ordering without retaining every context's analysis snapshot.
Progress at a new context starts its own deadline; unit progress and cancellation
cannot extend it, and the plan-derived overall workspace cap remains absolute.

Focused verification of this follow-up checks only the affected workspace
paths: the two-context diagnostic/refresh regression, existing workspace
diagnostics and symbol resolution (three passing cases), and the scheduler's
context/overall/cancellation deadlines (one passing case). An independent
stdio replay against the original checkout's 13 discovered build contexts
returns 106 clean reports in 77.277 seconds, followed by a nonempty hover and
clean shutdown, with the unchanged 512 MiB heap cap. Receipts are
`build/lsp-debug/acceptance/workspace-{context,deadline}-tests.log` and
`workspace-heap-final.{json,jsonl,log}`. The intermediate replay exposed the
aggregate 30-second timeout; another client attempt stopped at its own
45-second wait before that wait was corrected. Neither is a passing run.
At the user's request, the full suite is deferred until debugging is complete;
native Windows and editor-host checks are not rerun for this follow-up.

The subsequent installed `22b701bcd` run reached the fixed 120-second cap
while still elaborating a context. That cap incorrectly assumed four time
allowances regardless of workspace size. The worker now announces its plan
once, and the supervisor derives an absolute allowance for planning plus all
contexts (420 seconds for 13 contexts), retaining the 30-second per-context
deadline. Repeated plans or invalid context indices are rejected.

The same bounded progress metadata now reaches `window/logMessage` at info
level and client-supplied work-done tokens. Context starts are immediate;
file/phase, checked/reused units and elapsed time are refreshed about every
five seconds, including while waiting for the next worker observation.
Short document checks stay quiet until two seconds, and reported work logs
completion. The VS Code client needs no custom protocol or UI logic.

Verification for this follow-up is limited to two scheduler cases and two
protocol cases: simulated 130-second progress without sleeping, plan-derived
absolute expiry, stalled-context and cancellation deadlines, heartbeat
throttling/content, and info/work-done reports preceding final diagnostics.
All four pass; receipts are `build/lsp-debug/acceptance/progress-*-tests.log`.
No full workspace replay, broad suite, editor host or native Windows LSP
run is repeated for this change.

The `117beacc7` editor log then exposed repeated idle sweeps: VS Code's pinned
language client polls workspace diagnostics two seconds after each response.
Recomputing every context on every poll also evicted foreground snapshots,
causing another document check and refresh; an opened Basis context eventually
led to another heap failure. Workspace diagnostics now use a separate worker
and retain only bounded JSON reports and content fingerprints between polls.
Each background context releases its analysis before the next one starts.
Background restart cannot invalidate foreground result IDs, and cancellation
routes to the correct worker even when their job numbers coincide.

The focused idle-poll regression fails against installed `117beacc7` and
passes with the fix. It covers repeated/unchanged reports, saved library
changes, regenerated manifests, changed build membership, new root builds
and unsaved overlays. Existing workspace diagnostics and progress cases pass
as well. The first candidate missed `IO.Io` for absent manifest probes;
the corrected three-case run is `idle-loop-regression-fixed.log`.

An independent replay checks only `rune.build`, never all 13 contexts. It
checks hover while the background analysis is outstanding, three cached polls,
foreground snapshot survival and clean shutdown. The polls take 0.330,
0.318 and 0.308 seconds, with no additional `unit-start` observations; final
hover takes 0.008 seconds. The background retains about 1.3 MiB after a forced
collection. Receipts are `idle-loop-real-project.log` and
`workspace-heap-idle-candidate.{json,jsonl}` under
`build/lsp-debug/acceptance`. Full suites and editor/native Windows LSP
runs remain deferred under the debugging rule.

Read-only navigation in `f592a4eb9` exposed another invalidation path. Opens,
closes and save preparation unconditionally dirtied the workspace; identical
configuration replies did so again and refreshed every editor presentation.
The background cache also included open-buffer membership, making an opened
Basis file expand the sweep from 13 to 14 contexts. Separately, the program
and Basis graphs evicted each other under one foreground source budget.

Saved-text navigation and inherited/no-op settings now preserve the workspace
generation and unrelated presentations. Closed-project diagnostic scope stays
independent of open tabs and document context choices. Cache fingerprints
follow effective overlay/disk content, and cached report versions reflect
current buffer state. Unsaved opens, discarded changes and actual settings
changes still invalidate analysis. A lazy Basis foreground worker keeps its
graph separate from program and background workers; each retains the existing
512 MiB heap / 1.5 GiB address-space bounds. Waiter sharing, cancellation and
restart invalidation distinguish the owning worker despite overlapping job IDs.

Focused navigation regressions fail against `f592a4eb9`. Three controller
cases and three affected protocol cases pass with the fix; the Basis case
also overlaps program/Basis requests to check waiter isolation. The real
replay uses only `rune.build` plus foreground Basis browsing, with scoped
configuration responses, an in-flight workspace pull, three Basis
close/reopen cycles and F12. It performs no newly checked units after warmup:
each reopened Basis reuses all 278 units. Warm Rune hover takes 0.010-0.011
seconds, definition 0.226-0.253 seconds, reopened Basis hover 0.660-0.698
seconds, and cached workspace pulls 0.330-0.371 seconds. The workspace pull
survives navigation and exits cleanly on shutdown.

Receipts are `navigation-controller-final.log`, `navigation-protocol.log`,
`navigation-worker-isolation.log`, `navigation-real-project.log` and
`workspace-heap-navigation-candidate.{json,jsonl}` under
`build/lsp-debug/acceptance`. The first real-replay assertion incorrectly
counted `unit-start` visits as checks; observations showed zero checked and
278 reused units. The corrected assertion counts checked units and passes.
No 13-context replay, broad suite, editor host or native Windows LSP run is
added for this follow-up.

The `0597c4446` log exposed a remaining foreground loop between the Rune
project (more than 2 MiB of captured text) and loose-source contexts. Eviction
caused a recheck, and every completed check requested a global diagnostic
refresh, which could restart that cycle. Individual document polling also
needed a path independent of semantic-view residency. The connection now
retains bounded diagnostic identities/bodies (512 / 4 MiB), returns cached
full/unchanged reports, and requests refresh only for a changed report or
foreground input generation. Real changes coalesce across a pending refresh
without losing dependency updates. Memory/process limits are unchanged.

A concurrent-query probe found another eviction race: dependent queries
shared priority with fresh checks, letting several checks evict the first
view before its queries ran. Queries now precede those checks. The count-limit
eviction probe fails before this fix and passes afterward.

Ambiguous-context errors were also cached as infrastructure failures and
survived choosing a context. Waiting for selection now returns typed
`ServerCancelled` with `retriggerRequest=false`, which the pinned VS Code
client handles without error logging. Choosing a context advances foreground
generation, clearing the old failure/request identity. A separate closed-project
input generation preserves background diagnostic reuse and independent
pending prompts while still invalidating on actual source/settings changes.

Focused acceptance comprises four protocol cases (refresh, eviction/refresh,
concurrent query eviction and context recovery) plus one controller case for
independent pending choices. The old build fails the two original regression
probes. The first candidate context reply used the wrong private-wire data
encoding; that was corrected. Its test also initially assumed action order;
it now selects the named context and checks the resulting type.

The real replay uses one `rune.build` context and one loose List-using buffer.
After evicting the Rune semantic graph, 16 alternating full/unchanged document
polls complete in 0.0072 seconds with no additional checked units or refreshes,
and shutdown exits zero. Receipts are `refresh-context-final.log`,
`refresh-context-controller.log`, `query-eviction-baseline.log`,
`refresh-loop-real-project.log` and
`workspace-heap-refresh-context-candidate.{json,jsonl}` under
`build/lsp-debug/acceptance`. The full suite, 13-context sweep, editor host
and native Windows LSP remain deferred under the debugging rule.

An idle `53c6bceb0` sample isolated the remaining CPU load to the background
worker (17.5% of one core over two seconds while both foreground workers
were idle). Cached workspace polls still hashed all captured text every time.
Acknowledged watch coverage now skips hashing covered inputs, retaining
content checks for uncovered paths, registration failure and a periodic
60-second full validation. A new watch baseline is validated before trust.

The watcher lifecycle and cached-workspace protocol cases pass, including
notification-driven invalidation and fallback after registration refusal.
The focused `rune.build` replay validates 251 covered inputs without content
hashes: five cached polls take 0.066 seconds total (12-14 ms each), versus
0.350 seconds for the preceding full baseline validation. It checks equal
reports and zero exit. Receipts are `watched-cache-{controller,protocol}.log`,
`watched-cache-real-project.log` and `workspace-heap-watched-cpu-candidate`
under `build/lsp-debug/acceptance`; no full suite or 13-context sweep is run.

The outline follow-up replaces flat occurrence projection with named syntax
scopes joined by compiler binding identity. The four declarations of
`mkRelative`'s `h` share one identity; its separate clause-local `p` variables
have distinct identities. Function/module/declaration ranges supply nesting,
with exact name selection ranges and function kinds from syntax and frozen
type facts. Hierarchical clients receive `DocumentSymbol` children; legacy
document and workspace clients retain flat locations. Workspace resolution
continues validating its original symbol token and captured generation.

Three focused protocol cases pass: the new scope/binding outline fixture,
existing navigation/symbols, and workspace symbol resolution. The fixture
checks merged clauses, distinct parameters, shadowed function/parameter names,
function-valued `val` declarations, datatype children and range containment.
The real `lib/basis/ospath.sml` replay passes in 5.186 seconds including cold
Basis analysis: `RunePath` contains function `mkRelative`, its `path` parameter,
one function `h` covering four clauses, and two distinct `p` children. The
initial harness incorrectly expected module name `OS_Path`; the source's
actual name is `RunePath`, and the corrected replay exits zero. Receipts are
`outline-protocol.log`, `outline-real-ospath.log` and `outline-ospath.json`
under `build/lsp-debug/acceptance`. Full suite, editor host and native Windows
LSP checks remain deferred under the debugging rule.

The public compiler adapter now reports missing-library manifest errors as
`Failed` diagnostics. Discovery can then report an unavailable target instead
of aborting with the exception name `Usage`.

## Reproduction and measurement

`tests/lsp/project-replay.sml` is the independent protocol client. Supply
the VM, server, source root and a new result file explicitly. Opening the
three-line entry point analyzes the entire compiler target. The harness
checks the provider burst, warm hover, project navigation, completion and
normal process exit. Set `RUNE_LSP_REPLAY_CYCLES=100` for leaf-edit cycles;
every tenth revision introduces an explicit `int`/`bool` mismatch and the
next repairs it.

Set `RUNE_LSP_PROFILE` to an absolute JSONL path for phase, allocation and
request observations. A separate run with `RUNE_LSP_PROFILE_GC=1` collects
after each command returns, measuring retained state rather than temporary
command data. Forced-collection runs do not supply query latency claims.

Raw baseline logs, source hashes, the original VSIX and measurement results
are under `/home/ruud/rune-benchmark-results/lsp/2026-10-24-live-debug`.
Build/editor receipts are under `build/lsp-debug/acceptance` in the worktree.

The final implementation's 100-edit retention pass produced 308 post-command
collections. After discarding the first 30 samples, live data stayed between
271,072,816 and 271,086,744 bytes. The first and last 30-sample medians were
both 271,081,344 bytes; maximum process-tree RSS was 417,332 KiB. Each warm
leaf check reused 230 of 231 units. This pass had no worker failures. The
tracked ledger is `tests/lsp/baseline/2026-10-24-resident.json`; raw results
and the exact measured package are retained in `retention-optimized`.

The Linux and native Windows real-project replays both passed. The isolated
VS Code host also exercised the actual project providers and error/repair
workflow. Initial GUI attempts exposed missing-manifest reporting and
workspace-pull scheduling races; their failed logs are retained. Follow-up
checks must be recorded separately rather than treating those attempts as
clean acceptance.

A controlled Linux JIT comparison used identical VM/image bytes and changed only
worker JIT mode in a private launcher. Forty repetitions with optimizing JIT
measured p95 hover 22.702 ms, definition 27.297 ms, repeated completion
4.049 ms and leaf diagnostics 941.950 ms. Cold diagnostics took 9.576 s and
the first uncached completion 407.865 ms. These meet the proposed 250 ms
hover/navigation, 500 ms completion and 1 s leaf-diagnostic gates. No forced
collections were enabled. Raw `latency-jit-opt` and tier-one comparison
results remain separate from the retention run. The shipped policy selects
optimizing JIT directly, without the experimental launcher.

## Acceptance receipts

Production code at `e2688dc14` passed the unrestricted final full check:
**19,863 PASS, 3 SKIP, 0 FAIL**, 3,532.5 seconds wall time
(`make-check-final.log`, `tests/out/r/20261024-022246-2607123/summary.md`).
The skips are the two documented native interrupt cases and the missing
separate pinned GMP `native` prefix. Earlier full receipts remain separate:
the previous unrestricted run passed the same count, the sandbox attempt
could not execute native 32-bit SML/NJ (exit 159), and the original
distribution acceptance recorded five crash/output-limit failures.

The library profile passed **281/281**, including compiler-library tests on
all six native hosts (`library-profile.log`). The separate six-way Basis
matrix passed **2,747**, with **151 documented unsupported-host skips** and
no failures (`matrix-six-configs.log`). The complete `make matrix-quick`
receipt, including MLKit, is `matrix-quick-final.log`, run
`20261024-022320-2611440`; its final verdict is included in `final.json`.
The runner serializes MLKit compilations through its matrix pool.

The full LSP suite passes, including 45 semantic protocol cases, process
supervision, cancellation, snapshot isolation and changed completion/index
invalidation (`optimizing-worker-lsp.log`). Native Windows passes all 45
protocol cases, six worker-supervision cases, the frozen-analysis tests and
five process/reaping cases. The updated client/staging/version checks pass
all eight runner cases, including their planted-fault canaries.

Forcing a development VM rebuild with the packaged server and worker alive
passed all **11** package/library checks, including actual manifest
regeneration (`development-rebuild-linux-final.log`). Before/after SHA-256
receipts show the private VM and server unchanged. The development VM was
published by an atomic rename because the matrix runner was executing its
previous inode; its rebuilt bytes were identical as well.

## Isolated editor acceptance

VS Code **1.106.0 and 1.142.0** pass the real-project editor workflow
(`editor-final-minimum.log`, `editor-final-current.log`). Those initial
runs used private profiles and a separately downloaded Code build.

VS Code **1.143.1** also passes on Linux inside bubblewrap with a private
Xvfb display (`editor-1.143.1-sandbox-quiet.log`). A further run also passes with the
extension and worker executable paths containing spaces and Unicode
(`editor-1.143.1-sandbox-paths.log`). The namespace has no host
home, Windows drives, WSL interop socket, host display or network. Editor
and runtime files are read-only; source, profiles and results use private
copies. The mount policy and result are under
`build/lsp-debug/rune-editor-sandbox-2j0bwd3b/results`.
The machine-specific driver and privately extracted Xvfb dependencies are
retained in `build/lsp-debug/acceptance/editor-sandbox.py` and
`build/lsp-debug/sandbox-deps`.

A portable Windows **1.143.1** build passes in Windows Sandbox: full Rune
project initialization/diagnostics, hover, navigation, completion, restart
and error/repair. All 45 semantic cases and all 10 packaged Basis/library
checks also pass inside that guest, without Rune on `PATH`. Its private
source path contains spaces and Unicode, and the Code file URI uses the
encoded, lower-case Windows drive form. The configuration maps only
read-only inputs and a dedicated writable results directory. Networking,
clipboard, microphone, camera, printers and vGPU are disabled; Protected
Client is enabled and guest memory is 4096 MiB.

The launcher in `editors/vscode/test/windows-sandbox-launch.ps1` starts
minimized, records PID/creation-time ownership outside the writable guest
mapping and waits for a nonce-matched completion marker after logs close.
It then disposes only the owned processes from the host. The guest does
not call Windows shutdown. The lifecycle smoke check confirms two minimized
windows and all owned processes gone. The full functional run also passes
while minimized; its first cleanup exposed a vanished-window race after
client disposal. The VM was already gone when checked independently; the
fixed lifecycle rerun confirms cleanup (`windows-sandbox-background-recheck.log`).
The corrected combined run confirms both minimized windows and all owned
processes gone, with no guest shutdown. Its functional/lifecycle receipt is
`windows-sandbox-minimized-final.log`. The subsequent path-coverage run
also passes with the private Windows extension binaries under
`C:\Work\Rune extension Ω` (`windows-sandbox-paths.log`). See
[the test guide](../../editors/vscode/test/README.md) for the prepared-case
format and commands. This host runs Windows build 22000 and lacks the newer
headless `wsb` CLI, so the legacy desktop client is used minimized.

## Failed attempts and limits

Failed attempts remain preserved and are not reclassified by later passes.

- The installed `f4ee51368` package exhausted its heap repeatedly; baseline
  logs and the exact original package remain in the external results tree.
- Initial GUI attempts exposed a missing-manifest exception and a workspace
  diagnostic scheduling race. Both were corrected and the follow-ups pass.
  The initial restricted GUI launch also lacked permission for local IPC.
- The first informative-error assertion found a started child PID without
  its executable path. Errors now always include the executable; the
  corrected focused checks pass (`further-requests-checks-final.log`).
- A candidate archive check compared a privately rebuilt server with the
  different `bin/runelsp.rbc` and rejected it (`candidate-archive.log`). The
  final normal archive/payload checks are recorded in `final.json`.
- A native Windows replay over the WSL UNC share exceeded the unchanged
  30-second deadline during concurrent full-check/matrix/semantic load.
  `project-windows-optimized.json` identifies its worker, Rune build,
  document and last parsed compiler file. A separate native-storage replay
  passes (`project-windows-native-rerun.log`), as do guest replays.
- The first isolated Linux 1.143.1 run timed out while clearing diagnostics;
  a profiled follow-up reached the cold Rune check's worker deadline during
  full-check load. The non-profiled follow-up after that load ended passes.
- A loaded/profiled Windows 1.143.1 editor run timed out waiting for hover,
  although analysis completed. The quiet run passes, including the encoded
  Windows URI. A combined Windows profiling capture contains one fragmented
  JSONL record and supplies no performance acceptance claim.
- The installed Windows editor's updater blocked early GUI launches with
  `vscode-updating`; the launcher returned zero even though no test provider
  ran. Native GUI acceptance was completed using a separate portable Code
  build inside Windows Sandbox, leaving the installed editor alone.
- Windows fixture setup initially omitted ignored/generated manifests;
  the corrected fixture passes. Native `tar.exe` could not use a Unicode
  extraction destination, so extraction uses an ASCII directory followed
  by a Unicode rename. A script-policy block was rerun with a process-local
  override without changing system policy.

The independent structured protocol assertions, editor PASS markers and
process-exit checks determine acceptance; a GUI launcher's zero exit alone
is insufficient. Forced-GC retention results and loaded/profiling attempts
remain separate from Linux latency measurements.

Final artifact generation follows the acceptance commit to preserve Rune's
Git-derived version. `build/lsp-debug/acceptance/final.json` records the
artifact's exact commit, version mapping, hashes and post-build checks.
