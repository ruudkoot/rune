# Unit testing, part two: finish the SML/Rune migration

Written 2026-10-20 and reconciled after the rebase against
`80694b6b7` on `origin/master` at `78192dfd9`, in `.worktrees/unit-testing`.
The status table below records implementation progress. This continues
[unit-testing.md](unit-testing.md), particularly the
unfinished parts of M13 and M14 and the drivers deferred by M10 and M11.
Its inventory replaces the first roadmap's historical script counts as a
description of what remains at this revision.

The result should be that SML owns test discovery, scheduling, scenarios,
protocols, comparisons, expectations, limits and reporting. Calling an old
shell or Python driver from an SML job does not complete its migration.
Make still builds prerequisites; compilers, debuggers, qemu and independent
reference programs remain processes that the SML runner invokes.

## Starting point and scope

The runner, unit/property libraries, language and Basis jobs, most compiler
oracles, portability orchestration, native library host tests and colour
checks already exist. Reuse `tests/runner/{sh,lang,basis,laws,oracles,tools,
protocols,portability,hosts,libhosts,hostchecks}.sml` and `lib/test/runner`.
Do not introduce another scheduler or subprocess supervisor for these ports.
The host and colour migrations are complete; they are precedents, not new
work for this roadmap.

Full acceptance after the rebase recorded 17,253 results: 17,251 passes and
two documented native-interrupt skips. Rune and MLton produced identical
runner bytecode. Per-case events and the summary from
`tests/out/r/20261020-222530-889970` are copied into the P2.0 baseline.
The earlier temporary build log was not retained; its absence is recorded,
and the baseline keeps the command from the preceding rebase validation.
These are baseline results, not acceptance of ports implemented later.
The native host inventory now contains 24 programs on each of six hosts;
the first roadmap's 20-program shadow comparison remains historical evidence.

The tracked inventory under `scripts/`, `tests/` and `tools/` contains
**288 files: 224 shell and 64 Python**, plus **12 AWK helpers**. The canonical
per-file inventory is [migration.tsv](../../tests/runner/migration.tsv).
It assigns every file a milestone, comparison contract and baseline Git blob;
retired rows also name their SML replacement. Appendix A groups that inventory.
The rebase added 134 benchmark checks and nine other scripts to the previous
145-file census. Embedded Python/AWK programs are part of their owning driver;
moving them into an unregistered helper is not a completed port.

There are two completion boundaries:

* **Finish test control:** P2.0–P2.13, accepted by P2.17. This completes the
  deferred migrations and removes shell/Python assertions from test drivers.
* **Convert the remaining development tools:** P2.14–P2.16, also accepted by
  P2.17. These extend D23 to measurement, generators and production build/package
  tools that it explicitly excluded. The owner's instruction of 2026-10-20 to
  work through all milestones authorizes this complete scope. Keep these
  commits separate from the test-control ports and preserve bootstrap order.

Nineteen files have explicit reasons to remain: nine bootstrap/setup helpers,
two installers under test and eight independent Python oracles/peers. The
other **269 shell/Python files and all 12 AWK helpers** have conversion
milestones. A future decision to convert
an exception needs an independent oracle or a working bootstrap replacement;
counting zero `.sh`/`.py` files is not the acceptance criterion.

Archived tool snapshots under `examples/benchmarks/results/`, upstream bug
reproducers under `docs/bugreport/`, example reference oracles and environment
hooks are outside this live test/tool inventory. Preserve their provenance.
Audit extensionless scripts and embedded shell recipes too: an extension
change must not hide test logic from the final audit.

## Rules for every port

1. **Capture the old contract first.** Record cases, configurations, flags,
   inputs, expected bytes/statuses, skips, deviations, limits and artifacts.
   Compare case identities and verdicts, not just total passes. A skipped or
   silently dropped case cannot replace a previous pass.
2. **Run old and new on the same source state.** Keep both implementations
   until shadow runs agree. Use separate output roots with the same relative
   source names, inputs, binaries and environment. Record justified differences
   explicitly; never accept generated expectations blindly.
3. **Plant faults.** Exercise a wrong expected result and a suite-specific
   defect. For drivers supervising children also exercise a loop, crash,
   output flood and leaked descendant. A printed `PASS` followed by failure
   must fail. Reuse the existing canaries and host-adapter checks.
4. **Keep resources and dependencies explicit.** Reuse bounded process groups,
   deadlines, output caps, pools and DAG edges. Build privately, execute from
   the repository root where fixtures require it, and publish shared caches
   atomically. A failed producer must wake its consumers with a failure.
5. **Make each retirement reviewable.** Delete a script in the commit that
   replaces its last caller. Update the inventory, Make targets, capability
   declarations, affected-path coverage, tiers/profiles and
   [testing.md](../testing.md) in that commit. Document intentional CLI changes
   and replacement rerun commands. Remove Python/tmux requirements only after
   the selected jobs no longer need them, including their independent peers.
6. **Validate the resulting route.** Run focused old/new comparisons, planted
   faults, `make check` and applicable library/VM/layout profiles. Compare
   Rune- and MLton-built runner bytecode after runner changes. Report missing
   tools, sandbox restrictions and host bugs separately from successful runs.

Keep SML code portable across supported hosts: do not assume an `Int` width,
reimplement JSON/protocol libraries or calculate large counts through `real`.
Keep byte-level and structured JSON expectations distinct. New runtime APIs
need signatures, documentation, tests and all system-layer implementations.

## Milestones

The sequence below is a recommended implementation order, not a requirement
to serialize independent ports. Every row in Appendix A names its primary
owner; a shared helper can remain until that milestone's last dependent lands.

| Milestone | Depends on | Delivers | State |
| --- | --- | --- | --- |
| P2.0 | existing runner | Current inventory and reproducible comparison baseline | done 2026-10-20 |
| P2.1 | P2.0 | Native-code checks and stress/sanitizer ways | done 2026-10-21 |
| P2.2 | P2.0 | Census, simulator, layout and gcbench checks | done 2026-10-21 |
| P2.3 | P2.0; P2.6 for host benchmark execution | Budgets and benchmark correctness | pending |
| P2.4 | P2.0 | Documentation consistency and law mutation checks | done 2026-10-21 |
| P2.5 | P2.0 | Shared matrix model, probes and host laws | in progress: model and controller implemented |
| P2.6 | P2.5 | Full Basis/benchmark matrix execution | pending |
| P2.7 | P2.1, P2.6 | Windows ways and final legacy VM/language runner retirement | done 2026-10-21 |
| P2.8 | P2.0 | Build/dependency/unit/install/distribution scenarios | done 2026-10-21 |
| P2.9 | P2.0; P2.6 where matrix execution is shared | Incremental edits and external corpora | done 2026-10-21 |
| P2.10 | P2.0 | IntInf correctness and hardening drivers | done 2026-10-21 |
| P2.11 | P2.8, P2.10; P2.7 for Windows paths | GMP build/download/install/cross tests | done 2026-10-21 |
| P2.12 | P2.0; P2.7 for Windows paths | REPL protocol, DAP, kernel and interop orchestration | done 2026-10-21 |
| P2.13 | P2.0; runtime pty support | Terminal scenarios and tester display checks | done 2026-10-21 |
| P2.14 | relevant correctness ports and P2.6 | Measurement and analysis tools | done: 43 controllers retired; public SML measurement CLI |
| P2.15 | P2.4, P2.6, P2.9 | Post-bootstrap generators | done: 25 producers retired; native/xc1/xc2 and full inventory agreement |
| P2.16 | P2.8, P2.11; bootstrap design below | Build/provisioning/package tools | pending |
| P2.17 | P2.1–P2.13; P2.14–P2.16 for extended completion | Retirement audit and final acceptance | pending |

### P2.0 — Freeze the inventory and comparison baseline

* Enumerate tracked scripts and all callers in Make, the runner, CI, docs and
  other scripts. Add executable scripts without a `.sh`/`.py` suffix to the
  audit. Identify already redundant drivers before attempting a port.
* Capture `rune-test list`, profile selections and tool identities. Preserve
  the rebased full-check per-case baseline; capture each remaining legacy
  suite's per-case results when its port begins, before changing that suite.
  Store commands, source revision, dirty-state
  snapshot, configuration, seeds, exit statuses and logs in a dated validation
  directory. Keep a baseline available after deletion via its Git revision.
* **Exit:** every active driver has an owner and a comparison procedure;
  baseline failures and deviations are recorded rather than treated as passes.

### P2.1 — Native checks and stress/sanitizer ways

* Port runeopt loader/refusal cases, assembly fixtures, count comparisons,
  native bootstrap byte equality, debug line tables and debugger checks into
  per-case SML jobs. Preserve current opcode coverage and skip semantics.
* Express stack/register/native stress, ASan, JIT and deoptimization variants
  as ways using existing language/oracle machinery. Port the native wrapper's
  translation/cache policy into SML; retain only a thin executable entrypoint
  if callers need a VM-shaped command. Keep necessary assembly helpers as
  tool adapters until their own semantics are accounted for.
* **Exit:** counts, debug locations and bootstrap bytes agree; corrupt assembly,
  a wrong count, stale cache and bad debugger location are detected. Exercise
  the actual stress/sanitizer paths, including ASan's address-space needs.
  `run-tests.sh` remains until P2.7 closes every other caller.

### P2.2 — Census, simulators, layouts and gcbench

* Port census stdout/count/table/summary/static checks and `checktrace.py`'s
  NumPy-backed trace validation to typed SML readers. Preserve unsigned widths,
  byte order, bounds and the distinction between an empty and a missing file.
* Port heapsim/gcsim synthetic cases, replay validation, layout checksum
  comparisons and gcbench self-checks. Model trace creation as a producer with
  explicit invalidation and failure propagation; make the stock VM, trace and
  simulator use the same workload, directory, inputs and collector settings.
* **Exit:** old/new checks and validation bands agree; corrupt/truncated trace
  records, missing samples, wrong byte totals and checksum errors fail. Keep
  existing numerical tolerances unchanged and test their boundaries. Routine
  census validation no longer silently skips because NumPy is absent.

### P2.3 — Instruction budgets and benchmark correctness

* Port deterministic budget comparison and `--new`/`--update` behavior without
  automatically accepting values. Replace smoke/catalog/classic/pilot/state/
  queens/measurement-test control with named SML jobs and existing catalogue
  data. Include the Python inventory tool's unit-test harness, even though
  the tool itself is a later production-tool port.
* Share the matrix's program-list/input/data contract instead of parsing its
  printed summary. Keep independent benchmark oracle programs as separate
  commands; port orchestration around them.
* **Exit:** wrong counts, invalid metadata, perturbed complete-state fixtures
  and failed benchmark children are rejected before a success is reported.
  `make check` retains correctness/count checks; timing stays outside it in an
  exclusive pool. P2.14 owns measurement production, not these fault checks.

### P2.4 — Documentation consistency and law mutants

* Move language/test coverage, manifest, signature/claim and deviation/note
  comparisons into SML. Exercise generated documentation through runedoc's
  existing interfaces, with read-only checking separate from generation.
  Replace mixed generators' test-time `--check` calls with SML comparisons of
  temporary generated output; add an output-directory option where needed.
* Port law-mutant discovery, compilation and killed/survived/invalid outcomes.
  Preserve seeds, mutation counts, exclusions and law watchdog behavior.
  Generation helpers may remain until P2.15; SML owns the assertions now.
* **Exit:** missing and duplicate rows, stale claims/notes/annotations,
  signature-token drift and a surviving mutant each fail a named check.
  A failure of the checker itself cannot masquerade as a killed mutant.

### P2.5 — Matrix model, probes and host-law runner

* Define typed compiler/library/target configurations and explicit capability,
  probe, compile, run and result phases. Reuse host discovery, overrides and
  bounded adapters from `hosts.sml`; preserve all matrix configuration names,
  CLI selections, environment overrides and deviation classifications.
* Port `run-laws-hosts.py` on that model, including property case limits,
  retries/skips and host output normalization. Keep per-host distinctions;
  the native-library host runner does not by itself cover the Basis matrix.
* **Exit:** each host's availability and error probes agree with the old
  drivers; a host that exits zero after a compile error fails. Every selected
  law/configuration is accounted for, including stale expected failures.
  Pin and record MLKit plus its library; serialize its source-adjacent caches.

### P2.6 — Full Basis matrix, including section recovery and images

* Replace `run-matrix.sh`'s orchestration for Rune, native hosts, xc1, xc2,
  Windows and portability configurations. Represent configurations as ways;
  preserve compile-section splitting/bisection so a host rejecting one section
  does not erase independently loadable checks later in the program.
* Preserve heap-image production/restoration, host Basis preparation,
  program-list/input/data modes, resource controls and performance-mode
  outputs used by benchmarks. Foundational source generators may be invoked
  as explicit steps until P2.15; summaries and expectations belong to SML.
* **Exit:** shadow `matrix-quick`, full `matrix` and representative external
  program/data/performance modes. Plant an early section failure, missing
  image, stale deviation and failed preparation. No selected configuration
  disappears, and image consumers cannot wait forever on failed producers.

### P2.7 — Windows launching and legacy runner closure

* Port Windows staging/path selection, WSL environment propagation and
  per-VM language/runtime execution. Share rejection fixtures with the SML
  runtime checks already used locally; reuse portability's count/image
  oracles rather than embedding a second VM test implementation.
* Route stress, sanitizers, Windows and portability through their ways. Move
  `skipped.sh` callers onto `Expectations`. Replace residual shell test loops
  in Make, keeping build recipes and OS launch operations as thin adapters.
* **Exit:** actual `test-windows`, `test-portability`, stress and sanitizer
  selections agree, including stack/register/JIT variants and image routes.
  Probe paths with spaces and unavailable targets. Delete `run-tests.sh`,
  `run-vm-tests.sh`, `run-windows.sh`, `windows-dir.sh` and `skipped.sh` only
  when the caller audit is empty. P2.12/P2.13 finish their own Windows drivers.

### P2.8 — Build, dependency, unit, install and distribution scenarios

* Translate deps/dynamic/buildfile/units scenarios into SML or the existing
  cram format where it expresses ordered command/output fixtures. Preserve
  negative diagnostics, exact recompilation behavior and byte comparisons.
* Port staged install, relocation, uninstall and distribution archive tests.
  Make remains an operation under test; `scripts/install.sh` and distribution
  installers remain subjects of the checks. Exercise archive metadata and
  ELF/PE rejection with deterministic fixture binaries, not system installs.
* **Exit:** every old scenario and platform branch has a named replacement;
  wrong exports, missing members, broken relocation and malformed binaries
  fail. Both MLton and SML/NJ installation paths run. A cram transcript that
  merely invokes the former suite script does not satisfy this milestone.

### P2.9 — Incremental edits and external corpora

* Port incremental scenarios, random edits, corrupt-cache planting and the
  MLton incremental scenarios. Use isolated project copies and compare warm,
  cold and whole-program results, exact rebuild sets and cache verification.
* Preserve Python random-edit sequences by implementing its required PRNG/
  selection semantics with golden vectors, or freeze versioned edit traces
  before deliberately introducing a new generator. The initial shadow run
  must use identical edits. Keep the corrupt-cache writer independent enough
  to manufacture an invalid entry rather than relying on the production writer.
* Port external MLton regression/benchmark and host-Basis probing drivers;
  preserve corpus provenance, skip reasons, prepare/list/update modes, inputs
  and expected counts. External trees remain externally provisioned data.
* **Exit:** replayed edits, rebuild sets and corpus verdicts agree; stale cache,
  changed dependency and missing external input are detected. Only command
  startup failures qualify as unavailable tools; corpus failures remain failures.

### P2.10 — IntInf correctness, backends and hardening

* Port corpus generation/execution, packed-storage boundaries, option bounds,
  GMP/forced-SML backend comparisons, image checks and allocation/fork/limit
  hardening. Preserve generated-source bytes, report hashes and all VM modes.
* Keep the expected arithmetic independent of Rune's IntInf implementation:
  capture and review the existing Python vectors, and/or compile an SML
  reference with a native host's own IntInf. Replacing Python integer answers
  with answers from the same Rune backend would remove the oracle.
* Move `run.py`'s optional benchmarking/reporting path onto shared SML
  measurement support too before deleting that file; separate test verdicts
  from timings. Keep sanitizer-specific resource policies explicit.
* **Exit:** old/new vectors, hashes, outputs, statuses and image behavior agree;
  a wrong big-integer answer, storage boundary, failed allocation and broken
  limit/fork policy are detected on GMP and GMP-free builds.

### P2.11 — GMP build, download, install and cross tests

* Port build-configuration/mode, dependency regression, CPU dispatch,
  download, staged install and cross-platform test drivers. Preserve GMP-free
  binaries before rebuilding the GMP variants; record each binary's identity.
* Replace Python import/mock test harnesses with deterministic CLI seams in
  the tools under test and fixture executables/archives driven from SML.
  Keep policy in the production tool and assertions in the SML tests. Test
  download retries, checksums and atomic publication without live networking.
* **Exit:** offline fault scenarios agree; no failed/partial download becomes
  a valid cache entry. Exercise all required cross targets, widths, byte orders,
  CPU families and producer/consumer image pairs. Missing toolchains are
  recorded as incomplete coverage. Build/package implementations can remain
  Python until P2.16 without keeping Python test assertions.

### P2.12 — Protocol drivers and interop orchestration

* Write REPL protocol and DAP drivers on `lib/jsonrpc`/`lib/dap`; port kernel
  control and the in-house kernel client on `lib/jupyter`/`lib/zmtp`. Preserve
  pipe/connection engine ways, framing, byte expectations, interrupts,
  shutdown, authentication and asynchronous message ordering constraints.
* Port Jupyter/ZMTP interop launch/control while retaining their independent
  Python peers. Keep `notebook_client.py` using Jupyter's third-party client
  as an interoperability oracle, separate from the SML protocol tests.
* Replace `kernel/windows.py`'s ctypes event/process orchestration with an SML
  driver and the minimum runtime system-layer support needed for inheritable
  interrupt events and child handles. Implement every system layer; do not
  leave a Python launcher holding the substantive protocol/process policy.
* **Exit:** old/new transcripts agree on POSIX and Windows; invalid frames,
  signatures, response IDs, lost interrupts and premature child exits fail.
  Socket validation needs an environment that permits loopback connections.

### P2.13 — Terminal support and the tester's display

* Implement the first roadmap's G8 prerequisite: a documented pty interface,
  POSIX implementation and Windows ConPTY path, with an explicit unsupported
  system-layer result where appropriate. Separate terminal capability from
  the availability of a particular external terminal program.
* Port terminal scenario parsing, input, resize, raw-mode, interrupt and
  screen assertions to SML using `lib/terminal` and its `Emulator`. Replace
  `run.sh`, `term.py` and `ptyraw.py`, including their Windows paths.
* Add the deferred tester-display checks: capture the runner's own drawing
  and check final frames, progress, failures, resize and non-TTY behavior
  through `Emulator` and plain-output fixtures.
* **Exit:** shadow the tmux/Python path before removing it; dropped keystrokes,
  stale frames, wrong resize and raw-mode restoration faults fail. Run the
  additional Windows/portability checks required by runtime changes. This
  milestone remains pending while G8 is missing.

### P2.14 — Measurement and analysis tools

* Move benchmark/GC/layout/IntInf measurement orchestration, sweeps, comparison
  tables and reports into SML tools. Reuse typed counts, workload metadata and
  trace readers. Preserve command-line modes and existing JSON/TSV schemas.
* Preserve warmups, repetitions, alternating paired runs, CPU affinity,
  resource caps, timer units, medians/quantiles and rounding. Split compile,
  run and formatting time; never compare elapsed seconds for exact equality.
  Keep platform counters/perf as external instruments behind thin adapters.
* **Exit:** feed identical captured measurements/traces into old/new reporters
  and compare exact discrete fields plus documented numeric tolerances. Check
  live measurement on representative paths, failed children and missing
  counters. Timing jobs use an exclusive pool and stay outside `make check`.
  Include the rebased benchmark provenance/result helpers, HOL kernel/theory
  runs, lexer corpus cost modes, JIT analysis and profiling AWK programs.

### P2.15 — Post-bootstrap generators

* Port annotation/compatibility tables, host-Basis and xc2 preparation,
  benchmark inventory, FXP inputs, signature/entity/Unicode tables and digest
  vectors to SML tools. Share parsers with existing SML build/catalogue code
  where their semantics match.
* Inventory the AWK helpers consumed by these scripts and the native assembly
  helpers from P2.1. Port transformation logic too, or document a genuinely
  external tool boundary; wrapping `awk` around the old program is not a port.
* **Exit:** generated manifests, source ordering, shims, tokens, tables and
  vectors agree byte for byte. Repeat generation and run concurrent invocations
  in isolated outputs; validate xc1/xc2 on the resulting sources. Keep
  pre-host `build-files.sh`, `gen-build-files.sh` and `gen-version.sh` bootstrap
  exceptions until an independently usable bootstrap design replaces them.

### P2.16 — Build/provisioning/package tools

* Port GMP configuration/build helpers, runtime build records/input discovery,
  runtime packaging, distribution construction and external MLton setup to
  dedicated SML tools,
  leaving Make as the build dependency graph. Preserve hashes, feature
  selection, cross flags, archive layouts, metadata and cache invalidation.
* Design the bootstrap before routing Make through Rune: GMP-free VM creation
  and distribution preparation must not require the VM they are building.
  A native-host-built SML tool is a candidate; prove its clean-checkout build
  order and record the host requirement before choosing it. Shared pure logic
  can have separate host-native and Rune entrypoints.
* **Exit:** clean host bootstrap, GMP/GMP-free builds, cross builds, install
  tests and packaging fixtures pass without the old Python implementations.
  Reproduce relevant artifacts and reject poisoned downloads/build records.
  Do not remove pre-host setup tools or installers merely to reduce the count.

### P2.17 — Audit retirement and accept the result

* Recount live scripts and classify new arrivals. Search every Make/CI/runner/
  documentation caller, embedded shell command and retained adapter for test
  loops, parsing, comparisons or verdicts that escaped the ports. Remove dead
  drivers and Python/tmux capability declarations only where no consumer remains.
* Compare case/configuration coverage, affected selection, rerun commands,
  cancellation behavior and output retention against P2.0. Check that compiler,
  runtime, Basis and build changes still select the required broad suites;
  do not narrow compiler/build coverage to obtain faster prose-only selections.
* Run full `make check`, library/host matrix, VM/stress/sanitizer, actual
  Windows and portability acceptance where applicable, plus planted faults
  and runner host/self-build byte equality. Record the exact tools, limits,
  skips, deviations and source state; resolve unexplained differences.
* **Core exit:** P2.1–P2.13 complete; remaining Python is an independent
  oracle/peer or a production/development tool awaiting its named extension.
  SML owns all test assertions and orchestration. Bootstrap/OS adapters stay thin.
* **Extended exit:** P2.14–P2.16 also complete; only the nineteen named retained
  files (or explicitly reviewed successors) remain in this inventory. Update
  both roadmaps and `docs/testing.md` with completed milestones and evidence.

## Appendix A — Remaining tracked script inventory

[migration.tsv](../../tests/runner/migration.tsv) is the complete, sorted
per-file ledger. Its columns are path, language, owner, state, baseline blob,
SML replacement and comparison contract. Every live shell/Python/AWK file in
`scripts/`, `tests/` and `tools/` must occur once. Retired entries stay in the
ledger with their replacement and recoverable baseline blob. The SML checks
`runner/migration-inventory` and `runner/migration-faults` enforce ownership,
retirement and rejection of incomplete or duplicate inventories.

| Owner | Shell | Python | AWK | Scope |
| --- | ---: | ---: | ---: | --- |
| P2.1 | 5 | 0 | 2 | Native wrapper, runeopt suites and bytecode assembly/real normalization helpers |
| P2.2 | 6 | 2 | 0 | Census, trace validation, simulators, layout/gcbench and JIT-dump regression |
| P2.3 | 142 | 1 | 0 | Budgets, benchmark orchestration, all 140 benchmark check scripts and inventory tests |
| P2.4 | 4 | 0 | 0 | Documentation consistency and law mutants |
| P2.5 | 0 | 1 | 0 | Host laws |
| P2.6 | 1 | 0 | 0 | Basis/program matrix |
| P2.7 | 5 | 0 | 0 | Legacy language/runtime, Windows launch and skip readers |
| P2.8 | 6 | 0 | 0 | Dependency/build/unit/install/distribution scenarios |
| P2.9 | 5 | 2 | 0 | Incremental scenarios, edits, planted cache corruption and external corpora |
| P2.10 | 0 | 5 | 0 | IntInf correctness and hardening |
| P2.11 | 0 | 8 | 0 | GMP build/download/install/cross tests |
| P2.12 | 3 | 4 | 0 | REPL/DAP/kernel and interop orchestration |
| P2.13 | 1 | 2 | 0 | Terminal scenarios, raw mode and pty driving |
| P2.14 | 22 | 19 | 2 | Measurement/reporting, benchmark provenance/results, HOL/lexer experiments, JIT analysis and profiling AWK |
| P2.15 | 12 | 5 | 8 | Source/table/vector generators, including performance fixtures and xc2 AWK transforms |
| P2.16 | 1 | 7 | 0 | GMP/runtime build, packaging and external MLton setup |
| Retain: bootstrap/setup | 9 | 0 | 0 | The nine pre-Rune/host helpers retained by D23 |
| Retain: installers under test | 2 | 0 | 0 | Two installer implementations remain subjects of tests |
| Retain: independent oracles/peers | 0 | 8 | 0 | Five benchmark oracles, Jupyter client and two independent protocol peers |
| **Total** | **224** | **64** | **12** | **281 conversion targets; 19 retained files** |

The bootstrap/setup exceptions must work before Rune or the required host is
available. Keep build-time `doctor` usable even when the SML test doctor cannot
start, and preserve the concurrent `gen-build-files.sh` regression introduced
at the baseline revision. Retained installers are tested behavior; converting
their test harnesses must not change that behavior. Independent peers keep
cross-implementation checks from becoming a library talking only to itself.

## Implementation evidence

* **P2.0 (2026-10-20):** reconciled 300 files (288 shell/Python and 12 AWK),
  including every rebased benchmark check. The complete TSV gives each file
  an owner, baseline Git blob and comparison contract. No additional executable
  scripts without one of these extensions were found in the three live roots.
  `migration-baseline` recorded source state, pending/untracked source copies,
  callers, tool hashes/versions, environment and all tier/profile selections in
  `tests/out/unit-testing-part2/baseline-80694b6b7`. It preserves the preceding
  17,253-result full-check events and summary; that run's temporary build log
  is unavailable. The inventory and its five planted-error checks passed with
  the runner canaries (7/7, `tests/out/r/20261020-230045-2`). Every subsequent
  port must still record its own old/new case results and faults before deletion.
  Full P2.0 acceptance passed 17,255 results (17,253 passes, two documented
  native-interrupt skips), `tests/out/r/20261020-230416-9081`; the retained
  build/test log is `tests/out/unit-testing-part2/p2.0-check.log`. Rune and
  MLton produced identical P2.0 runner bytecode. P2.1 draft modules were not
  wired into that validated runner and are validated separately.
  The runner later pruned that raw run directory under its five-run retention
  policy; the complete P2.0 build/test log remains. Subsequent milestone
  receipts copy events and summaries outside the runner's rolling directory.
* **P2.1 (2026-10-21):** retired all seven owned files. Native assertions,
  independent bytecode assembly, translation/cache policy and stress/sanitizer
  ways are SML. The remaining Basis stress selections explicitly bridge the
  P2.6 matrix. Old/new proof under `tests/out/unit-testing-part2/p2.1` covers
  6,192 language verdicts (including two native skips), another 2,064 GMP
  sanitizer verdicts, 155 byte-identical assembly fixtures, 589 legacy native
  assertions over 563 programs, 325 count comparisons and 328 debug tables.
  The native bootstrap matched after refreshing the embedded Git version.
  Faults cover corrupt assembly, missing executables, empty stale caches,
  diagnostic preservation, wrong goldens/counts/locations, crash/timeout/flood/
  leaked children and the hash adapter's failure/fallback paths. Both Basis
  stress selections passed. The native cohort passed 2,144 cases; its two
  sanitizer preparation failures were fixed and their rerun passed with the
  canaries (7/7). Full acceptance then passed **18,827 results: 18,825 PASS,
  two documented native-interrupt SKIP**, 1,446.6 s wall and 10,817.4 s CPU
  with eight workers. The complete log is `p2.1-check.log`; events, summary and
  command are copied under `p2.1/acceptance` outside rolling retention. Rune
  and MLton produced identical final runner, launcher and native-check bytes.
  The first two interrupted logs and the full pre-fix receipt are retained.
  Validation found and fixed relative fixture paths, insufficient compiler
  assembly limits and PWD/export-order differences in scratch directories.
  The launcher retains the existing native SHA tool adapter, with a checked
  result and portable SML fallback: large warm launches dropped from about
  0.38 s to 0.04–0.06 s (old wrapper 0.03–0.06 s in the same comparison).
  Command-line flags, names, inherited options, image paths and non-regular
  input delegation were compared separately. The new checks intentionally
  reject a successful compiler that produced no executable; scratch execution
  isolates program-created files while normalizing both compared environments.
* **P2.2 (2026-10-21):** retired all eight owned files and replaced their
  Make routes with `heap/*` cases. The SML binary reader checks unsigned
  little-endian records, totals, sample clocks/liveness, pointer kinds and
  store bounds without NumPy. Packed per-object tables use nine bytes plus
  sample tables and bounded input buffers. Independent old/new captures under
  `tests/out/unit-testing-part2/p2.2` matched all nine generated traces byte
  for byte, SATB events, the gcbench operation stream, four JIT index/role
  lists (excluding process addresses) and all ten copier replay rows (excluding
  measured GC duration). Routine traces use SML producers with explicit DAG
  dependencies and recipe publication; a failed producer invalidates its old
  recipe and cancels its consumer. Compatibility replay still invokes the
  P2.14 production census adapter when an archive is absent/stale, with the
  assertions and five-setting report in SML. JIT analysis also remains a
  P2.14 tool dependency, separately required from the binary checks.
  Planted tests reject truncated/corrupt records, wrong totals and checksums,
  invalid JIT code/locations, missing versus empty stores, and failures at the
  inclusive numeric tolerance boundaries. The integrated focused run passed
  **213/213**, followed by full acceptance of **19,028 results: 19,026 PASS,
  two documented SKIP**, 2,369.8 s wall and 14,712.6 s CPU with eight workers.
  Events, summary and command are archived under `p2.2/acceptance`, with the
  complete log at `p2.2-check.log`. A follow-up thin entrypoint fix preserves
  standalone replay from other directories; valid/corrupt trace and stale
  archive replay probes from `/tmp` passed. Final Rune/MLton runner and heap
  helper bytecode comparisons passed. Earlier standalone SML checks passed
  211/211; the premature seven-case invocation before the integrated build
  completed was only the inventory/canaries and is not acceptance evidence.

### P2.5 implementation checkpoint, 2026-10-21

The shared matrix model, native capability/diagnostic probes, independent
source scanner and host-law controller are now SML. All 18 resolved rows,
six native name probes and 2,178 dependency sets agree with the old route.
Controller faults cover zero-exit static errors, bad probes, stale executable
output, alternative law entries, regex errors and PASS followed by failure.
The canonical integrated working-tree check passed 19,036 results (19,034
PASS and two native-interrupt SKIP); its receipt is archived in
`tests/out/unit-testing-part2/p2.4/acceptance`. That snapshot includes other
in-progress ports. This checkpoint does not retire the Python driver or
claim full host-law acceptance: full shadows exposed host GC instability
and a short-deadline startup failure that are still being reconciled.

### P2.4 acceptance, 2026-10-21

Four shell drivers are retired: feature consistency, documentation claims,
notes and law mutation control. `DocChecks` verifies features, all 205 claim
pairs, 65 independent signature token streams, notes, annotations and
private signature-generator output. The feature census is unchanged at 197
features, 326 language tests and 235 Basis files. `make check-docs` passed
all generated-page/lint checks and 11/11 runner cases.

`Mutants` preserves the 14 sources, evenly spaced sites, property seed,
watchdog and KILLED/SURVIVED/STILLBORN distinction. Char's two sampled sites
agree on SURVIVED/STILLBORN; List and ListPair agree on SURVIVED/KILLED with
the same killer law. Survivors now fail named adequacy verdicts, while the
final report still publishes all collected outcomes. Missing/duplicate
metadata, signature drift, stale annotations/notes, failed
producers, loops, crashes, floods and leaked descendants are covered.

The canonical `make check JOBS=8`, outside the sandbox with MLKit 4.7.25
pinned, passed 19,034 cases and two documented native-interrupt skips
(2,418.6 s wall). Its per-case receipt is preserved in
`tests/out/unit-testing-part2/p2.4/acceptance`, beyond rolling-run retention.
`p2.4/final-compilers/agreement.json` records matching Rune/MLton
bytecode for the final integrated runner, documentation checker, host-law
helper and matrix helper. The old mutation driver returned success
for survivors; its stricter replacement CLI is documented in testing.md.

### P2.5 acceptance, 2026-10-21

All 1,756 selected law verdicts agree with the former driver on each of MLton,
Poly/ML, pinned MLKit 4.7.25 and both runnable 64-bit SML/NJ releases. Evidence
is in `tests/out/unit-testing-part2/p2.5/full-host-shadow.json` and its referenced
result files. Both native SML/NJ releases showed moving fatal GC failures with
the default process layout. Their accepted shadow comparisons use the same
validation-only fixed-address wrapper, 64 MB initial allocation and 120-second
idle limit on both drivers; production defaults are unchanged. The 32-bit
release's Word64 startup defect remains an explicit unavailable framework.

The final controller rejects unknown PASS labels, accounts for every law after
library or program failure, continues collecting later programs and fails the
comparison on controller errors. Empty regex selections and stale selection
files cannot masquerade as success. Planted failed-library, failed-program,
unknown-label and diagnostic probes passed, including ordinary `Posix.Error:`
check labels. The integrated controller/section/image fault tier passed 7/7
(`p2.6/fixed-faults.log`). The canonical integration before retirement passed
19,034 tests with the two documented native interrupt skips; a fresh integrated
check also runs after the retirement and other completed ports. The original
Python source is retained only in the ignored acceptance baseline and Git.

### P2.6 acceptance, 2026-10-21

The shell matrix is retired. The standard full selection passed 6,142 runner
cases (5,620 passes, 522 explicit unavailable-structure skips), with all 3,055
program/configuration results shadowed. Three floating-point program changes
match existing HOST-FLAKY rules; the fourth difference is a baseline native
SML/NJ32 timeout whose later checks completed in the new run. No expectations
or library implementations were changed to obtain agreement.

All 1,175 host-library-on-Rune results also agree with the legacy driver.
The initial comparison exposed eighteen section-recovery failures: a Rune
type check was incorrectly treated as an interactive SML/NJ/Poly session
because of the library's name. Compiler identity now decides that behavior;
all affected programs were recollected and the complete comparison has zero
differences. Initial failed receipts remain under before-xc2-session-fix.

Public program/input/data mode agrees byte for byte on Rune and native Poly/ML,
including data paths with spaces. Calendar/compress2 shadows cover two
optimization levels. Four timing configurations preserve output/repetition
contracts; busy-machine timings are validation, not a performance claim.
Exact --one selection and missing-compiler failure were exercised. The final
fault tier passed 8/8, covering section recovery, images, failed preparation,
stale deviations and actual legacy/version-2 cache imports. Counter wrappers
prove hits avoid compilation and changed source, compiler or library inputs
invalidate it; changing only the execution VM retains bytecode reuse.
A fresh 32-bit preparation preserves accepted/dropped source decisions and
records the first real diagnostic. Main reports, timing sidecars and dropped
source tables remain available. Evidence is under tests/out/unit-testing-part2/p2.6.

### P2.3 acceptance, 2026-10-21

All 143 owned drivers are retired. All 267 benchmark output streams agree
with the old routes, including the six existing fluid/pidigits5/zarith
failures at O0/O2; no expected answers were changed. The 125 primary
wrappers and six actual nofib delegates are recorded separately. Both
register and stack instruction budgets agree, including byte-identical
regular-file and piped stdin reports and artifacts.

The preserved inventory contract has 163 original cases and 261 hand
assertions, replayed through the production catalogue query seam. All
169 inventory runner cases passed, including wrong-expectation and added-row
property canaries. Routine correctness passed 25/25 and extended checks
38/38, including the independent peers. Budget faults passed 6/6 and cover
wrong counts, stale/failed producers, timeout, crash, flood, leaks and
explicit update margins. Measurement probes cover false success, exit7,
timeout124 and wrong numeric results before sample publication. Evidence
is in tests/out/unit-testing-part2/p2.3.

The combined integration collected 19,162 passes, four skips and nine
failures after a version change invalidated build provenance during the
run; the full failed receipt is retained. All failed paths and dependencies
subsequently passed 34/34 with stable inputs. Rune and MLton produced
identical runner bytecode. Final clean global acceptance is required by P2.17.

### P2.8 acceptance, 2026-10-21

All six scenario drivers are retired. The new dependency, build-file, dynamic,
unit, staged-install and distribution routes passed 96/96 supervised cases,
including actual Windows installer execution without registry registration.
Unit scenarios retain whole/units, both bytecodes, warm recompilation,
dynamic loading and eighteen loader/image refusal cases. All three install
forms (bytecode, MLton and SML/NJ) run from private prefixes and cover library
manifests, relocation, native translation, REPL/DAP/kernel entrypoints and
uninstallation. The old installation route recorded 129 passes with no failures;
the old distribution route also passed.

Distribution checks independently manufacture ELF/PE metadata fixtures, read
tar/zip headers in SML and inspect modes, ownership, timestamps, newlines and
members. Corrupt checksum and missing/duplicate archive members are planted
against an actual produced archive. Fixtures never execute synthetic binaries.
Compression decoding remains a declared native adapter. The source packager's
own self-test is not used as the oracle. Evidence is under
tests/out/unit-testing-part2/p2.8. The combined integration's three install
provenance failures were retained and subsequently passed in the stable
34/34 rerun; final global acceptance remains P2.17's required check.

### P2.9 acceptance, 2026-10-21

All seven owned drivers are retired. The integrated SML tier passed 116/116
checks (`tests/out/unit-testing-part2/p2.9/acceptance`). All 55 distinct legacy
scenario labels passed in isolated old/new roots. The frozen Python seed-1
trace matches all 70 success, rebuild-count and across-change reuse receipts;
the version-2 SML generator completed 75 additional pairs without disagreement.
Two actual repository commits preserve the old generated-input skip outcome;
a two-commit controlled corpus positively replays with the same 3 then 1
compiled units. Those skips are not claimed as historical compiler coverage.

The pinned MLton compiler at `5fe943391e539a502699327a6266b6e8e97939e1`
was prepared with 606 files. All eight S44-S48 phases agree in status and rebuild
count (606, 0, 1, 1, 241, 6, 0, 0); all eight bytecode payloads are identical.
The final warm and uncached builds also agree within each controller. Both
retain the 14 GiB availability guard and 12 GiB per-build address-space cap.
The SML copy guard accepts the corpus's legitimate parent-relative library
paths while requiring every destination to remain inside its private work tree.

All 246 external regression verdicts agree: 153 passes, 93 unchanged skips;
the 153 passing stdout streams and bytecode payloads are identical. Four
external benchmark counts match, including preparation and generated inputs.
All 208 files of the external Basis source tree have the same diagnostic class
(10 ok, 185 unbound, 8 fixity, 5 syntax). Planted cache disagreement, stale
entry, wrong counts, explicit updates, timeout and missing-input cases fail
through the actual public controllers. Evidence JSON files and logs are kept
under `tests/out/unit-testing-part2/p2.9`; the original drivers also remain in
Git and the ignored comparison baseline. The first regression attempt used
mismatched register/stack tools; its logs are explicitly excluded from acceptance.

### P2.10 acceptance, 2026-10-21

All five correctness drivers are retired, including run.py's optional
measurement path. The preserved Python corpus has 230 arithmetic pairs and
1,154 checks per implementation. Expected answers remain independent: frozen
Python integers plus the saved SML list oracle. All 150 packed-storage
boundary payloads are byte-identical to the original controller. All thirty
fixed/exploratory workload source/answer pairs agree byte for byte. The
versioned fixtures record original generator identities and SHA256 hashes.

The integrated tier passed 14/14; backend collection passed 108 bounded
subprocesses (the former 107 plus an explicit semantic compilation), and
hardening passed the same 57 subprocesses as the former driver. Native and
GMP-free fork/image/limit cases run. Sanitizer backend tests with allocation
stress also passed 108 subprocesses, and sanitizer hardening passed 57;
their large shadow mappings retain the explicit address-space exception.
Planted wrong answers on both GMP and SML, storage/limit false success,
broken fork/allocation policy and wrong measurement answers are rejected.

Both optional pairing routes ran all twelve workloads with warmups and
separate instrumentation. The oracle route also ran all three compiler
workloads: all three payload hashes agree after retaining the original
library-path spelling. Reports use schema 2 for the SML controller and
Subprocess wall/CPU/RSS metrics, retaining sources, answers, binary hashes,
samples, pairing, affinity and libc metadata. These concurrent validation
runs are not performance measurements. Evidence and the original driver
copies are under tests/out/unit-testing-part2/p2.10. Final clean global
acceptance remains P2.17's required check.

### P2.7 acceptance, 2026-10-21

The five legacy language/runtime/Windows/skip scripts are retired. Local and
Windows ways share LangChecks; VM refusal fixtures and count/image oracles
are SML modules shared by Windows and portability. Windows staging uses a
per-worktree path and private per-run directories. The root inventory names
preparation, compilation, execution and oracle dependencies individually.
The suite and skip CLIs are bin/rune-suite; Windows paths/refusals use
bin/rune-windows. Existing flags and explicit golden updates remain available;
outputs use the common runner receipt layout.

The actual Windows selection passes 2318/2318. All 1630 legacy/new language
verdicts and streams agree across stack/register, 32/64-bit and tier-2 ways,
with only three explained absolute source-path spellings in interrupt traces.
All refusal and count/image checks pass. Native refusal checks agree on all
30 cases for both instruction sets. Legacy/new skip-reader output agrees on
all three actual expectation files, with and without reasons. Six planted
faults cover false success, crash after correct output, an unavailable VM,
paths with spaces and skip categories/way selection.

The full portability run records 3953 PASS and six failures: three obsolete
count-source names in each instruction set, which the old implementation
silently omitted. Actual arithmetic, GC-allocation and array fixtures replace
those names and absent selected sources now fail. The complete count rerun
passes 15/15 including canaries. The original receipt is preserved, not relabeled
as a passing full run. All cross-width/endian language, refusal, image, JIT
bootstrap and Basis matrix checks passed in that full run. Stress plus
register/native sanitizers pass 4625 cases with one documented native-interrupt
skip (4626 total). Rune and MLton produce identical root worker bytecode.
Raw logs, comparisons and copied acceptance receipts are under
 tests/out/unit-testing-part2/p2.7; final clean global acceptance remains P2.17.

### P2.11 acceptance, 2026-10-21

The eight GMP test controllers are SML. Configuration covers eight policy
cases; isolated Make switches preserve pinned/disabled/pinned-again artifact
identity and both missing-prefix policies. All twelve legacy download tests
pass against the public download-only production seam; thirteen SML scenarios
also exercise the real child timeout, SIGINT cleanup and retained diagnostics.
Failed or partial downloads never become trusted cache entries.

The division regression passes on native, Linux32, big-endian PPC64,
AArch64, Windows64 and Windows32. Four CPU families and all three JIT tiers
have identical legacy/SML statuses, output, backend statistics and instruction
counts. Both preparation controllers preserve eight hashed disabled payloads
and five disabled platform configurations before enabling GMP. Both staged
install modes pass relocation, native output, relinking and uninstall checks.

The complete old/new cross runs each pass 557 bounded subprocesses, including
216 producer/consumer image pairs under both stricter saved/current limits.
All arithmetic counts, disabled payload hashes, forks and unavailable-backend
refusals agree. The enabled subject was rebuilt between runs to refresh its
production recipe identity; that recorded artifact change is not byte equality.
The SML root dependency/download selection passes 7/7 including canaries;
Rune and MLton compile identical worker bytecode. Raw logs and comparisons
are under tests/out/unit-testing-part2/p2.11. The Python production tools
remain pending P2.16; their CLI seams are the subjects, not imported test mocks.

### P2.12 acceptance, 2026-10-21

Seven legacy protocol controllers are retired. bin/rune-protocol-check uses
lib/jsonrpc, lib/dap, lib/jupyter and lib/zmtp, with bounded duplex reads,
framing, asynchronous stream draining, authentication and reply correlation.
All seven REPL transcripts retain their exact expected bytes, including JSON
spelling, Unicode and interrupts. DAP covers both editor sessions, frame
variables/evaluation, exceptions, UTF-16 columns, output, pause and shutdown.
The notebook client retains all executions, input, display and debugger checks;
its cell filename hash is frozen from the independent Python calculation.

Both engine ways pass against the old and new POSIX drivers. Independent
Jupyter/ZMTP peers pass under the SML launchers; third-party jupyter_client
passes both ways and remains an optional, explicitly named peer capability.
Native Windows SML DAP and notebook drivers pass alongside the legacy drivers,
including JPY_INTERRUPT_EVENT. The existing runtime event primitives cover all
system layers (ENOSYS where unsupported); Windows spawning now inherits the
Jupyter event as well as the Rune event, deduplicating equal handles. No Python
or ctypes launcher holds the Windows process or protocol policy.

Seven planted faults cover invalid signatures, response parents, malformed
headers, wrong response IDs, early exits and a lost interrupt. The first root
run exposed an engine leak on failure (20 PASS, 1 LEAK); its receipt is kept
in p2.12/before-cleanup-fix. Cleanup now interrupts and requests shutdown before
waiting for the kernel, and the complete integrated selection passes 21/21
without leaks. The old unsupervised exploratory engine was separately removed.
Rune and MLton compile identical final protocol bytecode. Receipts and raw
comparisons remain under tests/out/unit-testing-part2/p2.12. Final global
acceptance and the runtime-change platform reruns remain required by P2.17.

### P2.13 acceptance, 2026-10-21

G8 is implemented as Pty: owned sessions, numeric borrowed descriptors, an
ordinary child pid, resize and explicit close. POSIX creates a controlling
terminal/session; Windows resolves ConPTY dynamically; sys_none and Windows
without the API return ENOSYS. Three appended primitives change the ISA
fingerprint, so compiler, VMs, images and workers were rebuilt consistently.
The Basis API/signature and real nonblocking-full-pipe contract pass on native
stack/register, all four Windows configurations, Linux32, big-endian PPC64
and AArch64 (42/42 and 36/36 root selections for each focused matrix).

The old POSIX controller passes all twenty scenarios on the fresh REPL image;
its first stale-image run (sixteen passes, four version mismatches) is preserved.
The old Windows controller passes thirteen checks. SML matches all twenty
POSIX scenarios, all thirteen Windows64 checks and adds the thirteen Windows32
checks. Integrated selections pass 28/28 on POSIX and 33/33 on Windows,
including canaries, typed raw-mode restoration and runner-display capture.
Independent Python comparisons of 3208 captured-screen/raw-pattern vectors
agree exactly in byte offsets. Timing output is separate from byte verdicts.

Actual ConPTY validation exposed redirected-parent standard-handle inheritance,
OSC titles leaking into Emulator cells, and missing selective SGR resets.
The backend explicitly requests fresh console handles; Emulator consumes
control strings across writes and preserves style resets. Its resize clips
cells/styles/modes and erases partial wide clusters. Seven emulator test groups
pass. A native probe confirms that every ConPTY child's standard handle is a
console handle and output goes through the PTY, including under redirected
parent I/O. Nonblocking Windows pipe writes now expose EAGAIN for the
zero-byte PIPE_NOWAIT form, allowing finite SML input deadlines.

Faults reject wrong frames, dropped input, bad dimensions, a crash after
correct output, floods and closed sessions, and detect a deliberately bad
raw-mode restoration. Cleanup terminates background programs even when the
PTY leader exited first. The runner's real progress/failure output, styles,
resize, final frame and non-TTY output are checked through Emulator. All
scenario state and history are private. The restore scenario no longer embeds
shell assertions; its five status/termios checks are SML.

The additional API matrix exposed a missing default Windows directory in the
full Basis controller. It now shares WindowsDir and includes the run identity
in staging paths; the original failure receipt is preserved. Focused matrices
pass without an explicit RUNE_WINDOWS_DIR. Source, raw logs and archived root
receipts are in tests/out/unit-testing-part2/p2.13. The three legacy terminal
drivers are retired; their measurement caller uses the SML raw route. Rune
and MLton produce identical terminal and root worker bytecode. The public
filtered CLI and raw measurement route are also exercised. Final
whole-project frozen-source acceptance remains P2.17's required step.

### P2.14 acceptance, 2026-10-21

All 43 measurement/analysis controllers are retired. `bin/rune-measure`
provides their public modes; Make and the runner call it directly. Weighted
counters, allocation counts and recorded nanoseconds use exact integers.
`perf`, GNU time, taskset, flock and objdump remain external instruments.
Timing jobs are explicit exclusive selections outside `make check`; mathematical
MMU vectors and fault assertions remain deterministic checks. Current commands
are documented in tools/measure/README.md, and immutable archived results keep
their original command/source provenance.

Independent shadow checks cover 70 result categories, both repository identity
modes, fuel bisection, elaborator/perf grouping, 309 MMU vectors, all GC JSON
schemas and twenty text/row modes, three collector scoring outcomes, census
summary/graph streams, and eight actual runs per paired evaluation controller.
Exact benchmark rows agree in count, stats, fresh and repeated modes, including
Rune, native MLton, Poly/ML and SML/NJ. Configuration resolution stays private;
source snapshots and controller/VM/helper payload hashes identify the actual
measurement. Native and AArch64 JIT dumps, role tables and twelve literal
instruction/counter/diff fixtures agree with the original analysis.

Simulator/layout coverage includes all twenty configuration matrices, actual
small-trace sweeps and replay, old-field provenance, timeline/MMU models, six
layout reports, twelve first-generation reports, ten second-generation reports,
validation/pretenure reports and all ten GC harness report families. Additional
fixtures exercise nonempty bootstrap/compile-sigs answers, MLton aggregation and
both measured-pause calibration heaps. GC sample selection/spread/event schemas
and its locked route pass. Counter, heap sweep, profiling and layout fixtures
match exact deterministic tables; actual host perf counters also measure Rune
and MLton successfully. Phase measurements retain identical source-line counts.
Old/new REPL scripts agree byte for byte, including the 2000-line paste, and both
live drivers complete with private history/state.

All six IntInf experiments pass with two measured pairs and their original
warmups and alternating order. Fixed arithmetic answers, eight conversion-input
hashes, specialized library/bytecode/disassembly hashes and compiler output
hashes agree. Normal code has eight capability queries; specialized code has
zero. Verified dispatch reuse passes and poisoned bytecode is rejected. Timings
are independent observations, not exact-equality results or speed claims.
Timeout, crash-after-output and descendant faults are rejected and cleaned up.
The public measurement/JIT/MMU selection passes 12/12 after retirement. Rune and
the native MLton compiler produce identical final measurement worker bytecode.

HOL kernel/theory command, fresh-copy, cache and nanosecond-mtime contracts pass
against independent controlled peers. The installed live HOL tree could not run:
its buildheap wrapper names a removed VM under `.cache/claude-rune-drafts`.
The failed live receipt is retained; this is not a successful HOL benchmark.
The first JIT selection used an old worker of another ISA and is preserved
(9 PASS, 2 FAIL, 1 dependent SKIP); refreshing the worker gives 12/12. An IntInf
bootstrap validation also caught concurrent source-comment edits; that attempt
is retained, and the complete frozen-input comparison passes. Raw fixtures,
logs, old/new reports, retired source snapshots and root receipts are under
tests/out/unit-testing-part2/p2.14. P2.15, P2.16 and full P2.17 acceptance remain.

### P2.15 acceptance, 2026-10-21

All 25 generator/helper producers are retired. `bin/rune-generate` provides the
public modes and `bin/rune-inventory` its JSON/CLI inventory entrypoint. Make,
Budget, documentation, external-input and matrix callers use the SML producers.
Generator payload and data identities participate in host-library cache keys.
The pre-host build-list/version/provisioning adapters remain independent.

The generated 2125-entity table, 134 independent digest vectors, 2450939-byte
FXP XML input and fifteen module-language input cases agree byte for byte with
the former producers. FXP retains the original binary64 arithmetic and recursive
length text. Digest answers remain frozen independent Python hashlib/HMAC
oracles. Annotations and every host Basis source, signature and file/prelude
record agree. Stable SML topology reproduces signature source ordering; all 65
transcriptions pass token comparisons. Comments survive regeneration, an existing
handwritten signature is preserved, a missing skeleton is recreated, and changed
tokens/orphan signatures fail. Concurrent isolated annotation/signature runs pass.

All five Unicode tables and nine conformance datasets agree byte for byte.
A raw-UCD reference normalizer passes all 20,171 normalization records before
publication. Frozen identifier exclusions, all 220 profile blocks and the security
script/type/confusable invariants agree. Two concurrent isolated regenerations
reproduce all fourteen files. A poisoned source digest is rejected before any
output tree is created. All sixteen source digests are pinned; missing inputs
were verified before atomic cache publication.

The complete five xc2 preparations agree across 3111 generated/input files,
including final rewritten sources, primitive families, stubs, source order,
scoping and prefixes. MLton's intermediate C-type map alone uses canonical name
order instead of AWK hash iteration; its entries and all final files agree.
All six native structure probes agree on 1032 verdicts and the complete Markdown.
The inventory agrees on all 861 pinned-source records and all fifteen fields,
the full five-source CLI check and 164 complete query reply envelopes. Its 169
handwritten regression/fault jobs pass through the public tool after retirement.
Existing FEM/text-variable effects are preserved explicitly to avoid changing the
committed inventory during the port. No algorithm or credit is inferred from a
filename alone. Rune and native MLton compile identical generator bytecode.

The broad generated-library run recorded 4771 PASS, 468 named unavailable SKIP
and three failed jobs among 5242 results. Two failures were the stale/report
checks because the selection omitted the Rune reference; the third exposed a
new terminal-milestone test assuming a portable OS error-name spelling. The
complete Rune reference passes 482/482, and using its actual producer records
makes the strict stale audit and twelve-configuration aggregate report pass.
The test now checks the portable Posix.Error.again value; native Poly/ML reports
EAGAIN rather than the assumed lowercase name. Focused Rune/native Poly/ML/xc2
Poly/ML checks pass 24/24. Existing expected deviations remain intact. The
fifteen generated compiler-budget jobs also pass.

These checks additionally exposed missing PTY host primitive definitions and
feature/bytecode documentation from P2.13. The host boundary now supplies the
correct ENOSYS sentinels; the extension and all three primitives are documented.
Old/new host generation still agrees after that closure, and documentation
checks pass 11/11. The new whole-string-end regex entrypoint retains all 3208
independent byte-offset vectors for the existing terminal matcher.

The initial sandbox host build hit SIGSYS in the installed 32-bit SML/NJ runtime;
the complete outside-sandbox rebuild passes. The first matrix with missing PTY
host definitions was cancelled and retained. A fixture-symlink archival mistake
was stopped and its generated duplicate removed; bounded receipts preserve the
originals. Raw comparisons, source snapshots, corrected/failure logs and bounded
root receipts remain in tests/out/unit-testing-part2/p2.15. P2.16 and P2.17 remain
required; the final full matrix/check accepts the final frozen source state.
