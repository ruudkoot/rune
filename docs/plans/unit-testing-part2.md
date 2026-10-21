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
| P2.4 | P2.0 | Documentation consistency and law mutation checks | pending |
| P2.5 | P2.0 | Shared matrix model, probes and host laws | pending |
| P2.6 | P2.5 | Full Basis/benchmark matrix execution | pending |
| P2.7 | P2.1, P2.6 | Windows ways and final legacy VM/language runner retirement | pending |
| P2.8 | P2.0 | Build/dependency/unit/install/distribution scenarios | pending |
| P2.9 | P2.0; P2.6 where matrix execution is shared | Incremental edits and external corpora | pending |
| P2.10 | P2.0 | IntInf correctness and hardening drivers | pending |
| P2.11 | P2.8, P2.10; P2.7 for Windows paths | GMP build/download/install/cross tests | pending |
| P2.12 | P2.0; P2.7 for Windows paths | REPL protocol, DAP, kernel and interop orchestration | pending |
| P2.13 | P2.0; runtime pty support | Terminal scenarios and tester display checks | pending |
| P2.14 | relevant correctness ports and P2.6 | Measurement and analysis tools | pending |
| P2.15 | P2.4, P2.6, P2.9 | Post-bootstrap generators | pending |
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
