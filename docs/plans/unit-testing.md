# Roadmap: a testing library, and Rune's tests on it

Rune has a property library, `lib/test/property`, and no other testing
library. Its tests are run by about 150 shell, Python and awk scripts, 13,000
lines of them called from the Makefile. `make check` strings 32 runs of
them together, one after another, in about a quarter of an hour on 16 CPUs.

This roadmap plans three things:
- **A library under `lib/test`.** A portable core, `lib/test/unit`, in which tests are written as values of a signature. A Rune-only runner, `lib/test/runner`, which schedules them by the resources they need, records what each costs, and keeps what each failure printed.
- **Rune's own tests moved onto it**, script by script. Each milestone retires named scripts. This is the battle test of the library.
- **Tests chosen for the occasion.** The Makefile's targets and the agents' instructions say which tests a kind of change runs. The aim is less time spent testing, with the same coverage or more.

It was written on 2026-10-11 against `34b2b4c5`, the merge of the
install-test branch into master. It lives in a worktree, on branch
`unit-testing`.

What it rests on:
* **The code.** A census of the scripts (152 files under `tests/`, `scripts/` and `tools/`), the Makefile's test targets, the SML harnesses there are (`lib/test/property`, the Basis suite's `T`, the libraries' tests), and what the Basis offers a runner (*Where we are*, *What is different for SML, and for Rune*).
* **Measurements** on a snapshot of `34b2b4c5`: `make check` timed step by step with the machine's load sampled once a second; every call of a compiler or a VM logged; the duplicated work counted; schedules simulated over the logged jobs; the disk left behind (*The experiments*).
* **A prototype** of 937 lines, thrown away afterwards. It has a tree of tests, filters, a forking supervisor with timeouts and output caps, a scheduler, `tests/lang` and `tests/errors` run in three ways with the compiles shared, an in-process suite in a worker that is restarted after a crash, and planted faults (*The experiments*, E9).
* **The literature and the implementations.** About forty frameworks and runners in Standard ML, Haskell, OCaml and other languages, compilers' own harnesses included. Papers on test design, test dependence, flaky tests, test selection, scheduling, build systems and compiler testing (*What the literature says*, *What the implementations do*, *References*).

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done 2026-10-11 |
| M1 | `lib/test/unit`, and the libraries' tests on it | done 2026-10-12 |
| M2 | The runtime's part: a clock, a child's costs, processors, spawn with limits | done 2026-10-12 |
| M3 | The runner, with `make check`'s steps as its first jobs | |
| M4 | `tests/lang` and `tests/errors` in ways, compiled once | |
| M5 | The first calibration: tiers, profiles, `--affected` | |
| M6 | One engine for expectations | |
| M7 | The Basis suite on the runner | |
| M8 | Laws on the runner | |
| M9 | The differential checks as oracles | |
| M10 | The tools' suites | |
| M11 | The protocol suites in SML | |
| M12 | Requirements and the doctor | |
| M13 | The matrix, and the other machines | |
| M14 | The rest, and the tools for flaky tests | |
| M15 | The final calibration | |

The owner decided D1 to D24 on 2026-10-12, every one as recommended
(*Decisions*). M1 and M2 do not depend on each other or on anything else,
and can be done first.

## The request

The owner's brief, as written:

> - this is a draft roadmap for improving the testing framework in rune
> - we have a good sml/rune property checking library under lib/test/property but no (unit) testing framework. most of rune's testing is done by a very adhoc collection of shell and python scripts
> - the purpose of this roadmap is three-fold:
>   1) design such a library under lib/test
>   2) use it to replace much of the shell and python scripts currently in the repo. this simultaneously increase the code and testing quality of rune and demonstrate the testing library this roadmap designed is fit-for-purpose and battle-tested
>   3) calibrate the tests that are run to be appriate for the scenarios in which they are run by e.g. amending the Makefile and agent instructions. this should reduce the time spent on testing while not decreasing or even increasing test coverage
> - i think Haskell's HSpec (https://hackage.haskell.org/package/hspec) is a decent starting point but it also the only testing library i have experience with besides quickcheck so i may be bias. please do thorough research on the exisiting testing libraries out these and the academic literature to desing the right library.
> - i would imagine we would have a hierarchy of tests and test runners to developers and agents can easily pick the right set of tests to run for their change
>   - e.g we could have the "library test set" containing "basis library test set" containing "Word64 test set" etc. etc.
>   - agents and humans should be able to easily override the test set, exclude particular failing or flaky tests easily, resume test set from a particualr point etc.
> - our new unit testing framework should of course integrate will with he already existing property-based testing framework
> - out testing framework needs to deal with real world problem
>   - in-process and out-of-process testing (the former to give fast execution, the latter to deal with tests that may segfault, may required to be killed etc.)
>   - monitoring and recording/tracking of wall, user, system time of test and size of outputs generated (high disk usage is also starting to become a problem with rune's current test framework)
>   - a nice output using lib/terminal when a human runs in the terminal and the most informative output possible when directed to log and/or being used by an agent
>   - ensure that all output of failing tests are recorded for investigation
>   - the happy path is both being extremely fast when all test pass successfully and allowing for quick investigation when tests are failing
>   - being able to deal with flaky tests
>   - ensure tests can keep the cpu loaded 100% by having a (resource-based?) job scheduler rather than relying on adhoc scheduling of test subsets like we do today. possibly some very high-memory use tests or perforamance may also need to be dealt with appropriately.
> - replace as much of the testing shell and python scripts as is reasonable possible in the repo.
>   - for some tests they may be foundational (but then i would assume as part of an individual test case, rarely if every as testing frameworks/runner)
> - we will also have tests that rely on third-party software to be available and be run as part of some test (e.g. for differential testing)
> - i would imagine the test descriptions are written against some signature. then the overall testing runner can execture the tests in various modes: find test inventory (but do not run it), find declared third-party packages from the test set (and check if they are available as part of a test doctor step), actually execute the tests using some particular job scheduler.
**The owner's answers while this was written (2026-10-11):**
- **Where it was written:** in a worktree, `.worktrees/unit-testing`, on a new branch `unit-testing` from master, committed as M0 and not pushed.
- **What it rests on:** measurements, and a prototype that is thrown away. Nothing but this document lands in the tree.
- **The decisions** (2026-10-12): the owner took every recommendation, D1 to D24.

| The brief asks | Answered in |
|---|---|
| design a testing library under `lib/test` | *The architecture*, D1 to D10, M1 |
| replace much of the shell and Python scripts, and battle-test the library by it | D23, M3 to M14, *Appendix A* |
| calibrate the tests run to the scenario (Makefile, agent instructions) | D21, D22, M5, M15 |
| HSpec as a starting point; research the libraries and the literature | *What the literature says*, *What the implementations do*, D2 |
| a hierarchy of test sets (library > basis library > Word64) | D2, D4, *The tree* |
| override the set, exclude failing or flaky tests, resume from a point | D4, D16, D17, D19 |
| integrate with the property library | D5 |
| in-process and out-of-process tests | D9, D10 |
| wall, user and system time, and the size of outputs | D13, G1, G2 |
| disk usage | D15, E6 |
| `lib/terminal` output for people, the most informative output for logs and agents | D14 |
| all output of failing tests recorded | D14, D15 |
| an extremely fast happy path, and quick investigation of failures | D8, D9, D14, E3, E9 |
| flaky tests | D17, E7 |
| a resource-based job scheduler keeping the CPUs busy; high-memory and timing tests | D12, E1, E4, E8 |
| scripts kept where they are foundational, inside a test case | D23 |
| tests that need third-party software (differential testing) | D18 |
| tests written against a signature | D2, D10, *The tree* |
| modes: inventory, doctor (declared third-party packages), execution under a scheduler | D18, D19 |

## Where we are

### The scripts

E10's census counts 152 scripts under `tests/`, `scripts/` and `tools/`: 101
in shell (14,321 lines), 40 in Python (6,873) and 11 in awk (727). The
Makefile names 70 of them, 13,001 lines. By what they test:

| Area | Runners | Oracle | In parallel by | Timeouts |
|---|---|---|---|---|
| the language | `tests/run-tests.sh` (242 lines; 280 programs in `tests/lang`, 71 in `tests/errors`), `tests/runtime/run-vm-tests.sh`, two Python checks | output against the sidecars; the first error line | `xargs -P` | none |
| engines | `scripts/check-jit.sh`, `check-register.sh`, `check-levels.sh`, `check-units.sh`, `check-positions.sh` | equal output and equal counts across modes | `xargs -P` | `check-jit.sh` only (600 s) |
| reproducibility | `check-cross.sh` (seven builds of everything), `check-doc-cross.sh`, `check-opt-cross.sh`, `check-reproducible.sh`, the bootstrap | identical bytes | `xargs -P`, longest first | none |
| the Basis Library | `tests/basis/run-matrix.sh` (1,698 lines; 230 programs, about 139,000 checks; configurations `rune`, `rune:new`, `rune:jit`, `rune:opt`, the hosts, `xc1`, `xc2`, the other machines) | `PASS`/`FAIL` lines, explained by `deviations.txt`, stale lines failing | `xargs -P`, longest first from `timings.tsv` | 120 s a phase; `ulimit` for MLKit and Poly/ML |
| laws | `run-laws.sh`, `run-laws-hosts.py` | results against `law-skips.txt` | `xargs -P`; a thread pool of 3 | a watchdog of 60 s per case, resumed after |
| libraries | `tests/lib/run-lib-tests.sh` (298 lines), `run-hosts.sh` | a `PASS` line and no `FAIL`; `.expected`; hashes | serial | interop only |
| native code | `tests/opt/run-opt-tests.sh`, `run-counts.sh`, `run-debug.sh`, `run-bootstrap.sh` | refusals; equal output and counts against the stack VM; the debuggers' lines | `xargs -P` | none |
| the documentation | `run-doc-tests.sh`, `check-docs.sh`, `check-claims.sh`, `check-notes.sh` | `.ir`, `.md` and `.diag` files; consistency | serial | none |
| the compiler's tools | `tests/ir`, `tests/units`, `tests/incremental` (805 lines and `mutate.py`, 488), `tests/deps`, `tests/dynamic`, `tests/buildfile`, `tests/install` | dumps, compiled-file lists, equal bytes | serial | none |
| protocols and terminals | `tests/serve/run.py`, `tests/repl`, `tests/repl-protocol/run.py`, `tests/dap/run.py`, `tests/kernel`, `tests/terminal` (tmux), `tests/diagnostics` | transcripts and screens | serial | Python's, 30 s; a screen waited on for 20 s |
| other machines | `tests/run-portability.sh` (qemu), `tests/run-windows.sh` (WSL's interop) | as `run-tests.sh`, and counts equal across VMs | `xargs -P` | none (Windows) |
| the collector and the heap | `check-census.sh`, `tools/heapsim/test*.sh`, `tests/layouts/check.sh`, `tests/gcbench/check.sh` | checksums, closed forms, shadow heaps | serial | 120 s, `ulimit -v` |
| performance | `tests/perf/run-perf.sh`, `run-benchmarks.sh` | counts within budgets; the catalogue's oracles | serial | some |

* **The pattern of most runners.** A shell script calls itself with `--one ITEM` through `xargs -n 1 -P $JOBS`. Each worker writes `PASS` or `FAIL name: why` to a `.result` file, and the parent prints them in file order.
* **Each runner has its own** filter syntax, sidecars, skip list, `--update` and summary line.

### `make check`

`make check` (`Makefile:1395-1427`) is 32 steps, run one after another
because "the suite runs share tests/out". A step that names several goals
runs them at once, each with all `JOBS` CPUs: `test bootstrap`, `test-ir
check-levels`, the six REPL and IDE targets, and `check-cross check-docs
check-isa`.

* **Its time.** AGENTS.md says "about a quarter of an hour on 16". `docs/building.md` still says three minutes. `docs/plans/weak-points.md` records the growth.
* **The steps that dominate.** On a 4-CPU cloud machine: `check-cross` with `check-docs` (4.6 min), `test-basis` (2.4), `test-native` (about 2) and `test-opt` (1.5) (`cloud/ENVIRONMENT.md:149-160`).
* **On this machine, at `34b2b4c5`** (E1): 12,355 s of CPU, of which the steps kept 3.65 CPUs busy on average, 23% of the 16.
  - **Eighteen of the 32 steps are serial or nearly so.** The longest are `test-gc` (560 s, 3.4 CPUs), `test-native` (552 s, 1.4), `test-all` (515 s, 1.5) and `test-laws` (338 s, 2.4).
  - **Wall time.** It took 56 minutes on a machine that other work kept busy. AGENTS.md's quarter of an hour is for an idle one.
* **A hidden order.** `test-opt` and `test-native` read the `.rbc` files that earlier steps left in `tests/out` (`tests/opt/run-opt-tests.sh:139-142`), so the steps cannot be reordered freely.
* **Duplicated work.**
  - `tests/lang` is compiled and run in more than 30 calls of `run-tests.sh`, which compiles every program again on every call (`tests/run-tests.sh:72`).
  - `test-gc`'s four calls compile each program four times, into two different bytecodes.
  - In all, `make check` calls `run-tests.sh` 25 times, which compile the 351 programs 8,775 times. 5,967 of those compiles (68%) repeat one with the same compiler and flags: about 1,740 s of CPU, 14% of the whole (E3).

### What else runs, and when

* **Outside `make check`:**
  - `make test-windows` (about 15 minutes) and `make test-portability`;
  - `make test-stress`, `vm-asan`, `test-native-stress` and `test-native-asan`;
  - `make matrix-quick` and `make matrix`;
  - `test-lib-hosts` and `test-laws-hosts`;
  - the benchmarks.
* **AGENTS.md** asks for `make check` before finishing any change, with extras by kind of change:
  - a change to `runtime/register` adds `test-register-asan`, `test-stress`, Windows and portability;
  - a library adds `matrix-quick` and `test-lib-hosts`;
  - the heap and the emitters add `test-heap`;
  - a change to the system layer adds `make test-windows`.
* **CI** (`.github/workflows/check.yml`) runs `make doctor` and `make check` on every pull request and push to master, on Ubuntu 24.04 with a three-hour limit. After a failure it uploads `tests/out/matrix/report*.md` and the top-level `.stdout`, `.stderr` and `.expected` files.

### The SML there is

* **`lib/test/property`** (`Gen`, `Co`, `Show`, `Arb`, `Prop`, `Check`):
  - internal shrinking, seeds from names, replay tokens;
  - reports in the Basis suite's `PASS`/`FAIL` form;
  - `Check.laws`, a runner for law programs with its own filter, resume and skip, driven by environment variables (`RUNE_PROPERTY_ONLY`, `AT`, `AFTER`, `SKIP`, `REPLAY`).
* **The Basis suite's harness** (`tests/basis/harness.sml`, structure `T`):
  - `check`, `eq`, `eqReal`, `approx`, `raises`, `skipUnless`, `guard`;
  - output `PASS label`, `FAIL label -- why` or `SKIP label -- why`, then a `SUMMARY` line;
  - runedoc parses the suite's calls of `T` (`src/doc/doctests.sml`).
* **The libraries' tests.** Each defines its own `check` and ends with `PASS key: n failed`: about twenty near-identical copies (`tests/lib/digest/digest.sml:11` is one).
* **A scheduler in the compiler.** `src/driver/parallel.sml` forks children for `-j`, sends their output to files with `dup2`, and reaps them with `waitpid_nh` on any child.
* **The benchmark catalogue** is SML (`examples/benchmarks/shared/catalog.sml`), with its own validator.

### What the Basis offers a runner

* **What a runner can use:**
  - `Posix.Process`: `fork`, `exec`, `waitpid` and `waitpid_nh` on any child, `kill` of a process or a group;
  - `Posix.IO`: `pipe` and `dup2`;
  - `OS.IO.poll`;
  - `Posix.ProcEnv.times` (children's user and system time at the clock tick, 10 ms) and `setpgid`;
  - `OS.FileSys` and `Posix.FileSys` for directories, links and sizes;
  - `Runtime.catchInterrupt`, which turns Ctrl-C into `SML90.Interrupt`;
  - `lib/terminal` (`Style`, `Device`, `Emulator`) and `lib/json`.
* **What it lacks** (*What the runtime must add*):
  - there are no threads, and no handler of a signal other than SIGINT;
  - there is no monotonic clock: `Time.now` is `gettimeofday`;
  - nothing gives a child's peak memory;
  - nothing gives the number of processors, and there is no `setrlimit`;
  - `Unix.execute` leaves standard error inherited (`lib/basis/unix.sml:47`);
  - `RuneRuntime.spawn` (`lib/basis/runtime.sml:208-216`), which works on Windows too, is not in `RUNTIME`.
* **On Windows:** fork is an emulation, a second VM sent the parent's state (about 30 ms and 3-4 ms per MB of live heap). `kill` is `TerminateProcess`.

### Expectations and skips

| List | Lines | Format | Read by |
|---|---|---|---|
| `tests/basis/deviations.txt` | 904 | `config \| label \| CATEGORY \| reason`; HOST-BUG 497, WIDTH 65, HOST-FLAKY 49, XC1-NA 43, SPEC-AMBIGUOUS 40, WINDOWS 39, HOST-ABSENT 25, RUNE-DEV 2, EMULATED 2; a stale line fails the run, HOST-FLAKY excepted | `run-matrix.sh` |
| `tests/basis/law-skips.txt` | 30 | `label \| FAILS or UNTESTED \| why` | `run-laws.sh` |
| `tests/basis/law-deviations.txt` | 64 | as `deviations.txt` | `run-laws-hosts.py` |
| `tests/lib/deviations.txt` | 43 | as `deviations.txt` | `tests/lib/run-hosts.sh` |
| `tests/opt-skip.txt`, `windows-skip.txt`, `portability-skip.txt` | 1, 0, 0 entries | `NAME CATEGORY: reason` | `run-tests.sh --skip`, `grep` |
| `tests/external/mlton-skip.txt` | 94 | `NAME CATEGORY: reason` | `run-mlton.sh` |

Seven lists, four formats, five readers.

### Flaky tests

* **For Rune's own tests,** nothing: no retry, and no list.
* **For the hosts,** the HOST-FLAKY category (49 lines), which may match and need not.
* **For the laws,** `run-laws-hosts.py` runs a failing law again up to three times, and calls it FLAKY when its verdict changes.
* **The terminal tests** wait on the screen, never on time (`docs/testing.md`).
* **What the repository's notes record failing under load and passing alone:**
  - the fork and wait checks of `Posix.ProcEnv` and `Unix.exit`;
  - `OS.FileSys.hash/spread`, which needs inode numbers that vary;
  - SML/NJ's reals under parallel load;
  - Windows `.exe`s that WSL fails to start (`UtilAcceptVsock … accept4 failed 110`);
  - a socket test on Windows that hung for six hours.
* **In CI**, 9 of 168 runs in four weeks failed on a commit that passed unchanged on another run. The causes: a directory that an earlier step made, a SIGPIPE disposition inherited from the shell, and one documentation test not yet explained (E7).

### Disk and reports

* **How much.** `tests/out` holds 7.4 GB in the main tree: a hand-run census (4.4 GB), the matrix's 28 configuration directories (842 MB, kept forever, some under names that no longer exist), native code (411 MB) and the seven builds of `check-cross` (308 MB). Worktrees hold 5 to 8 GB each.
* **What is kept.** `run-tests.sh` keeps the bytecode and outputs of every passing test. The engine checks keep everything, and the benchmark runs leave temporary directories.
* **Reports.** `tests/out/matrix/report.md` is overwritten by every configuration's run, so after `make check` it is `rune:jit`'s report alone, and that is what CI uploads.
* **A fresh `make check`** leaves 2.7 GB in 121,640 files, all but the 426 MB translation cache from tests that passed (E6).

## What is different for SML, and for Rune

Most frameworks were designed for a language with reflection or a
preprocessor, threads, and tests that are functions. Rune's situation differs
in ten ways, and each shapes a decision.

1. **No reflection and no annotations.**
   * Elsewhere, finding the tests is done for you: JUnit finds `@Test` methods, Go and pytest functions by their names, Rust's `#[test]` makes libtest generate a `main`, and HSpec leans on `hspec-discover`, a preprocessor that writes the main module from the file names.
   * Standard ML has none of these. A test exists only where a value names it.
   * So tests are values: a tree that a suite exports, and that can be listed without running anything (D2). Which files are suites is a convention (D10).
2. **No type classes.**
   * HSpec's `shouldBe` needs `Show` and `Eq` instances, and QuickCheck's generators come from `Arbitrary`. In SML they are passed explicitly.
   * Equality types give `=` where the type has it. Elsewhere a printer, and an equality, are arguments: `Expect.eq Int.toString`, or the property library's `'a arb` record with `show` and `eq` (`lib/test/property/arb_sig.sml:11-12`).
   * A law's `=` is decided per type already (`docs/plans/quickcheck.md`, D6).
3. **No threads, and no signal handlers.**
   * Rune has no threads. A program catches SIGINT and nothing else (`Runtime.catchInterrupt`), so `Posix.Process.alarm` ends the runner itself (`docs/plans/weak-points.md:247-248`).
   * So a test that runs in the runner's process cannot be stopped from inside it: there is no watchdog thread and no alarm handler.
   * The runner is therefore one event loop, as make and ninja are: start processes, poll `waitpid_nh`, look at the clock and the files, sleep briefly. A test that may hang runs in a process that can be killed. For in-process tests that process is a worker, started again after the test it died in (D9).
   * `src/driver/parallel.sml` is the precedent in the tree: a fork, `dup2` to a file, and `waitpid_nh` on any child.
4. **A test program costs a compile.**
   * Compiling `hello.sml` takes about 38 ms (`docs/performance.md:627`). A program on `lib/test/property` was measured at about a second of CPU, with its libraries compiled from source (`docs/plans/quickcheck.md:1669`).
   * An ordinary program loads no code at run time: `_dynamic` needs `--units` (`docs/units.md`).
   * So a test program is a suite of many tests (D10), and libraries come compiled from the unit cache.
5. **The runner is built by the compiler it tests.**
   * A broken compiler or VM can build a runner that passes everything.
   * The guards:
     * canaries in every run, tests that must fail, time out, crash or overflow their output;
     * the MLton-built compiler kept ready as the runner's builder (D20);
     * the core's own tests run under a harness of a few lines (*Testing the tester*).
6. **Determinism is the oracle.**
   * `--count` is exact, the bootstrap reproduces itself byte for byte, and every engine allocates the same objects (`docs/testing.md`, *The three oracles*).
   * A Rune test that fails and then passes is either the machine (load: the fork and wait checks, `OS.FileSys.hash/spread`, a Windows `.exe` that WSL does not start) or a bug, such as a collector race.
   * A retry that turns either into a pass hides it. Retries are therefore declared per test, never blanket (D17).
7. **Five other compilers.**
   * A library beside the Basis must build on MLton, SML/NJ 110.99.9 in 64 and 32 bits, SML/NJ 2026.2, Poly/ML and MLKit (`make test-lib-hosts`), and must never work around their bugs (AGENTS.md).
   * The core of the library is portable Standard ML for that reason. Supervising processes needs what only Rune has, so that part is a separate library (D1).
8. **Exceptions are failures.**
   * A test fails by raising. `Expect.Failure` carries a message, and any other exception is an error, reported with `exnName` and `exnMessage`.
   * On Rune, `Runtime.trace` can say where; on the other compilers nothing can.
9. **The output files are the tests.**
   * Most of Rune's tests are golden tests. 468 sidecar files (`.expected`, `.stderr-head`, `.cwarn`, `.restore`, ...) hold what `tests/lang` and `tests/errors` must print and how they run. Across all suites there are 536 files of expected output, and `tests/doc`, `tests/ir`, `tests/repl`, `tests/diagnostics` and `tests/terminal` each have their own kinds.
   * A library for Rune makes a golden file as easy as an assertion, with one way to accept new output after review (D6).
10. **Paths are input.**
    * A program's name and its directory are strings on its heap, so they reach the counts (`docs/testing.md`, *What the input is*).
    * A runner therefore gives every job a directory of the same width. That directory looks like the root of the tree where a test expects one: `tests/out/` and a link to `tests/lang/`.
    * The prototype ran every program of `tests/lang` and `tests/errors` that way, in three ways, and none changed its verdict (E9).

## What the literature says

The reading depth of each work is in *References*: full text, part of
the text, or the abstract. Entries with a DOI were rebuilt from Crossref's
record.

### Tests, fixtures and isolation

* **The beginning.** Beck's Smalltalk framework (1994) already separates a *failure*, a problem checked for, from an *error*, one that was not. It builds each test's fixture afresh, records an error and goes on to the next test, and keeps the times. JUnit (Beck and Gamma, 1998) adds a name for every test "so you can identify it if it fails", and suites as composites of tests.
* **Shared state.** Meszaros (2007) catalogues why tests become erratic: interacting tests and suites, leaking resources, optimism about resources, and nondeterminism. The cure is a fresh fixture, or one that cannot change.
* **Dependent tests are rare and small.**
  - **How small.** Of 96 real dependent tests, at least 82% need two tests or fewer to show, and 61% go through shared static variables (Zhang et al., ISSTA 2014).
  - **How costly.** All but two of the 96 caused false alarms, and two hid a real fault, one for three years.
  - **What finds them.** Random orders found every dependent test the exhaustive searches found.
* **Isolation costs, so few pay it.**
  - **The cost:** isolating each test in a process of its own costs up to 618%, so only 5% of 351 Maven projects isolate every test class (Bell and Kaiser, ICSE 2014; Bell et al., ESEC/FSE 2015).
  - **What testing costs builds:** 41% of build time, and 90% for builds over an hour.
  - **Cheaper ways:** a lightweight container in the process (VMVM) cut suites' time by 62% on average. Knowing the dependencies makes running in parallel and selecting tests sound.

**For Rune.** A Rune test that compiles and runs a program is isolated by
construction, since it is a process. In-process tests share the worker's
top-level references, so a worker per suite with a fresh directory, and an
order that can be shuffled with a recorded seed, is the cheap middle way
(D9).

### Flaky tests

* **Causes.**
  - **The first study** (Luo et al., FSE 2014; 161 fixes in 51 projects): waiting for something asynchronous 45%, concurrency 20%, the order of tests 12%. 78% were flaky when first written. In 24% of the fixes the code under test was changed, and 94% of those fixed a real bug: "don't just disable flaky tests".
  - **The survey** of 76 papers (Parry et al., TOSEM 2021) confirms asynchrony and concurrency as the leading causes.
  - **In Python** (Gruber et al., ICST 2021): 0.86% of 876,186 tests are flaky, and about 170 reruns are needed for 95% confidence that a passing test is not.
* **The machine.**
  - **Resources:** 46.5% of flaky tests depend on the resources they run with, CPU above all, and are likely below one core (Silva et al., TSE 2024).
  - **Stressing them out:** Shaker found 95% of flaky tests by running them beside CPU and memory stressors, against 37.5% for plain reruns (Silva, Teixeira and d'Amorim, ICSME 2020).
* **Reruns.**
  - **In the same process,** reruns confirmed 23% of what reruns in fresh processes, with a clean build, confirmed (DeFlaker, ICSE 2018).
  - **Google's rule of "flaky until three failures in a row"** hides real breaks: a broken 15-minute test takes 45 minutes to show (Micco, 2016).
  - **Flaky tests still find faults.** They revealed more than a third of the regression faults in Chromium's CI (Haben et al., 2023).
* **History.**
  - **Apple** ranks tests by the entropy and the flip rate of their outcomes, and cut flakiness by 44% with under 1% lost detection (Kowalczyk et al., ICSE-SEIP 2020).
  - **Microsoft** retries a failure once, calls a later pass flaky, files a bug, and suppresses the known flaky failure for 30 days (Lam et al., ICSE 2020). Only 25-43% of the flaky failures it studied came back in 500 runs.
  - **New tests:** 75% of flaky tests are flaky in the commit that adds them (Lam et al., OOPSLA 2020).
* **What flakiness costs.**
  - At Google, about 1.5% of runs are flaky, and almost 16% of tests have been (Micco, 2016).
  - In one company, flaky tests took at least 2.5% of developers' time. An automatic rerun cost about 0.02 cents, a person's investigation $5.67 (Leinen et al., ICST 2024).

**For Rune.**
* **What Rune's flaky tests are.** Rune's oracles are deterministic. Its known flaky tests are of the resource kind: fork and wait under load, inode numbers, WSL's start-up of `.exe`s.
* **What follows:**
  - record the load and the slots with every result (D13);
  - leave room on a loaded machine (D12);
  - rerun only what is declared, in a fresh process, and report a pass after a failure as FLAKY, never as PASS (D17);
  - offer the Shaker mode as `--under-load` (D17).

### Selecting and ordering tests

* **The survey.** Selection, minimisation and prioritisation (Yoo and Harman, STVR 2012).
* **Safe selection** chooses every test that could expose a fault: the tests that run changed code (Rothermel and Harrold, TOSEM 1997).
* **The granularity that works is coarse.**
  - **Ekstazi** tracks the files each test class loads and cut end-to-end time by 32%, 54% on long suites (Gligoric et al., ISSTA 2015).
  - **Static selection** at the level of classes matches it, while selection at the level of methods is slower and less safe (Legunsen et al., FSE 2016). STARTS selects 35% of tests (ASE 2017).
  - **Tests that start processes** need the operating system's view: RTSLinux skipped 74% of such tests (Celik et al., ESEC/FSE 2017).
* **How people choose.** Developers choose tests by hand in most sessions (62% run a single test), and choose more than a tool would 73% of the time (Gligoric et al., ASE 2014).
* **History selects well.** Running a suite only if it failed recently, is new, or has not run for a while caught 70-80% of failures while running at most a third of the suites (Elbaum, Rothermel and Penix, FSE 2014).
* **Learned selection.** Facebook's model selects under a third of the tests that dependencies select, and still reports over 95% of failures. Its training data is cleaned by rerunning every failure up to ten times (Machalica et al., ICSE-SEIP 2019).
* **Few tests ever fail.** At Google 91% of tests always passed and 1.2% found a breakage. Selecting by distance in the dependency graph would have saved 42-55% (Memon et al., ICSE-SEIP 2017).
* **Ordering.** Failing tests first gives faster feedback (Rothermel et al., TSE 2001).

**For Rune.** Almost every test reads `bin/rune` and `bin/runevm`, which
change with every change to the compiler or the VM. So selection by file or
by build dependency selects everything for such changes. It pays for changes
to libraries, documentation, tools and tests (E11). Ordering by history
(failed first, then by critical path) costs nothing and helps every run
(D12, D22).

### Scheduling

* **Graham's bounds (1966, 1969).**
  - **Any list schedule** is within 2 − 1/m of the best on m processors.
  - **Longest first (LPT),** without precedence, is within 4/3 − 1/(3m).
  - **Anomalies:** more processors, shorter tasks or fewer constraints can make a list schedule longer, so a scheduler's gain is measured, not assumed.
* **With precedence:**
  - **Critical path first:** the highest static level first (HLFET) is near optimal in simulation (Adam, Chandy and Dickson, CACM 1974; surveyed by Kwok and Ahmad, ACM Computing Surveys 1999).
  - **With resources** such as memory, a bad list can be as slow as running serially (Garey and Graham, SIAM J. Comput. 1975). Resources and edges need care together: a long chain that holds a scarce resource must not wait behind small jobs.

**For Rune.** Critical path first, longest first among independent jobs,
memory and pools as resources, and exclusive jobs that drain the slots
rather than starve (D12; E4 measures it).

### Build systems

* **The framework.** A build system is a scheduler and a rebuilder. Ideally every task runs once and only if needed, with early cut-off when an output did not change, and results shared by the hash of their inputs (Mokhov, Mitchell and Peyton Jones, ICFP 2018 and JFP 2020).
* **CloudBuild** runs every task in a sandbox of its declared inputs, so a missing dependency is an error and not a stale hit (Esfahani et al., ICSE-SEIP 2016).

**For Rune.** A step keyed by its tool and the digests of its inputs, run
once per run, is a small part of that (D8). Caching results across runs is
a later step that the keys make possible.

### Testing compilers

* **Differential testing:** run several comparable systems on the same input, and a difference, a hang or a crash marks a bug. Shorten a failing input automatically. "A crash is never the right answer" (McKeeman, 1998).
* **Csmith** found over 325 bugs in GCC and LLVM by comparing compilers on generated programs that avoid undefined behaviour (Yang et al., PLDI 2011).
* **EMI** needs one compiler only: variants of a program that must behave the same on its inputs (Le, Afshari and Su, PLDI 2014).
* **The survey** names cross-compiler, cross-optimisation and cross-version comparison as the three differential oracles (Chen et al., ACM Computing Surveys 2020).

**For Rune.** It has all three as oracles already: the hosts' builds,
`-O0` against `-O2`, and the counts across engines. The runner makes them
comparisons between ways (D7, M9).

### Developers and CI

* **How developers test** (Beller et al., ESEC/FSE 2015 and TSE 2019):
  - developers spend about a quarter of their time on tests and believe it is half;
  - half do not test in the IDE at all;
  - a quarter of the tests cause three quarters of the failures.
* **What CI costs** (Labuschagne, Inozemtseva and Holmes, ESEC/FSE 2017):
  - 18% of CI's runs of a suite fail, and 13% of those failures are flaky;
  - in a failed build 0.38% of executions fail;
  - more than 99% of executions would be avoidable with perfect selection.
* **Build times:** the average CI build takes just under 500 s (Hilton et al., ASE 2016).

### Output for agents

* **SWE-agent's interface** (Yang et al., NeurIPS 2024):
  - **Its principle:** "environment feedback should be informative but concise".
  - **What it does:** capped search results, an explicit message where a command printed nothing, and only the first error shown.
  - **What it gained:** collapsing old observations raised the resolved rate from 15.0% to 18.0%.
* **What later work found** (2025-2026; *References*): masking old tool output halves an agent's cost with no loss, and pruning output to what the task needs removes 23-92% of the tokens.
* **Logs in CI:** removing their low-information lines saves about 40% of the tokens with little loss (MSR 2026).
* **What no study has done** is vary a test runner's output and measure an agent's success.

**For Rune.** The case for D14 is argued, not measured:
* nothing for a passing test;
* a failure first, with its cause and a short excerpt;
* the full outputs on disk, named by the test's path;
* a line saying the run is alive;
* one final line.

## What the implementations do

**How they were read.** About forty frameworks and runners, from their
documentation and, where behaviour mattered, their sources, as of
2026-10-11. HOL4 was read at upstream `develop`. Where a point could not be
confirmed, the drafts' notes say so, and it is not used here.

### In Standard ML

* **SMLUnit** (SML#'s, by Yamatodani) is HUnit in SML.
  - A test is a value: `datatype test = TestCase of unit -> unit | Test of string * (unit -> unit) | TestLabel of string * test | TestList of test list`.
  - Assertions take an equality and a printer (`assertEqual : ('a*'a->bool) -> ('a -> string) -> 'a assertEqual`), with combinators for every Basis type.
  - The runner is sequential and in-process, and prints `.`, `F` and `E`.
  - It has no filter, timeout, timing or machine output, and its exit status never says a test failed.
* **mltonlib's `unit-test`** (Karvonen) runs each test as it is registered, through a variable-argument fold. So it cannot list a test without running it. Equality, printing, generation and shrinking all come from one type-indexed representation, `('a, 'x) Generic.Open.Rep.t`.
* **QCheck/SML** (League) checks properties, and treats a directory of files as test cases: "useful … for regression tests of a compiler".
* **HOL4:**
  - Its `testutils` print a line per check and `OK` or `FAILED!` (`tprint`, `require_msg`, `shouldfail`, `timed`).
  - Its build has **self-test levels**: 1 quick, 2 moderate, 3 as long as needed. CI runs level 3 daily.
  - Holmake's time limit is one of **inactivity** since a job's last output.
  - Holmake schedules by **critical path over recorded child CPU time**. A committed seed of durations covers a fresh checkout, a local cache overrides it, and the seed's generator refuses to write an incomplete seed: "a missing entry looks exactly like a cheap one".
  - It flags a build-time regression only above both an absolute and a relative threshold.
* **Poly/ML's `Tests/`:**
  - `Succeed/` and `Fail/` are run in one compiler process, each test in a private name space, with the compiler's flags reset before each.
  - A test that raises `NotApplicable` passes. There is no timeout.
* **MLton's `bin/regression`:**
  - Ways are whole reruns of the suite with a flag: the CI's three code generators.
  - The `.ok` files have variants per platform.
  - Skips are silent.
  - A whitelist of known failures is not strict.
  - Nothing runs in parallel.
* **MLKit's `kittester`:**
  - A `.tst` file lists programs with tokens: expect a compile error, an uncaught exception, timing.
  - Under timing it polls `/proc/<pid>/status` every 50 ms for the peak memory, and reads `times ()` for the CPU time.
  - It writes an HTML report.
* **SML/NJ's regression tests:**
  - Four outcomes: pass; open bug, output unchanged; *possible bug fix*; fail. A known bug pins its current output, so a fix shows.
  - Failing outputs are kept in `bad.<arch>/`.
  - Each run has a CPU limit of 400 s.

### Elsewhere

| | Tests are | Isolation | Selection | Expected failures | History, order | Timeout, kill | Output |
|---|---|---|---|---|---|---|---|
| **HSpec** | a tree built in a monad (`SpecTree`); `hspec-discover` writes the main | in-process, threads | `--match`/`--skip` on `/` paths; prints a ready `--match` to rerun | `pending` | `--rerun`, its report keeps the QuickCheck seed | none per item | checks, specdoc, progress |
| **Tasty** | a value (`TestTree`); `withResource` passes `IO a`, so listing acquires nothing; dependencies resolved after filtering | in-process | AWK patterns on `.` paths | tasty-expected-failure, strict | tasty-rerun | per test | `--hide-successes`, ant XML |
| **OUnit2** | a value | `processes` runner: fork, workers killed with TERM, then KILL | exact path; unselected shown as skipped | `todo`, `skip_if` | a cache, `failfirst` order | by size (20 s to 1 h), enforced only by processes | JUnit, HTML |
| **Alcotest** | a two-level value, `Quick`/`Slow` | in-process | regex and case numbers | | | | each case's output in a file under a run directory |
| **ppx_expect, Dune cram** | expectations in the source; transcripts | | | | Dune caches tests as actions | cram: per command | `.corrected` files, `dune promote` |
| **LLVM lit** | a file with `RUN:` lines | a process per test | regex filters; `REQUIRES`/`UNSUPPORTED`/`XFAIL` feature expressions | strict: XPASS fails | `.lit_test_times.txt`, a failure stored as a negative time; order: failed first, then slowest | kills the children with SIGKILL, no grace | `--test-output failed`, JSON, xunit; `--update-tests` |
| **DejaGnu, GCC** | `.exp` files, `dg-*` directives | processes | | POSIX 1003.3 outcomes, XPASS fails | `compare_tests` between runs | INT, TERM after 5 s, KILL after 5 s | `.sum` and `.log` |
| **Rust compiletest** | annotations in the file | processes | `needs-*`, `ignore-*`, `only-*` | `known-bug` pins the output | stamps skip unchanged passing tests | none (warns after 60 s) | `--bless` |
| **GHC testsuite** | `all.T` in Python | processes | | `expect_broken`, strict; `fragile`: run, result ignored | | TERM to the group, then KILL; job objects on Windows | "framework failures" apart; perf metrics in git notes with a tolerance both ways |
| **pytest** | functions; fixtures by scope | in-process; xdist workers restarted after a crash, up to 4 × n | `-k`, `-m` | `xfail(strict)` | `--lf`, `--ff`, `--sw` | pytest-timeout | `tmp_path` kept for failed tests only |
| **Go** | functions; `t.Run` subtests | a binary per package | `-run` per `/` level | | a test cache keyed on the files and environment the test read | 10 min per binary | `test2json` events |
| **cargo-nextest** | the binary's tests, listed first | a process per test, argued at length | filtersets | | `-R latest` (experimental) | slow-timeout, then TERM to the group, grace, KILL; job objects | retries with FLAKY, LEAK detection, JUnit with `flakyFailure` |
| **Bazel** | targets with sizes | a process per target, sandboxed | tags | | cached results | by size or timeout class; TERM, then KILL after 15 s | `--test_output=errors`; a premature-exit sentinel file |
| **CTest** | `add_test` | processes | `-R`, labels | `WILL_FAIL` | COST learned from passing runs; last failures first | `TIMEOUT`, a signal, then the tree killed | `--output-on-failure`, JUnit |
| **Meson** | `test()` | processes, `setsid` | suites | `expected_fail` | `priority` | 30 s default, × a multiplier per setup; `killpg` TERM, KILL | `testlog.json` |
| **Automake, Autotest** | scripts | processes | `-k` keywords | `XFAIL_TESTS` | `make recheck` | | `.log`/`.trs`; Autotest keeps failed groups' directories with a script that reruns them |
| **JUnit 6** | classes; a discovered `TestPlan` | in a JVM | tag expressions | | | `@Timeout` | Open Test Reporting |
| **ExUnit** | modules | in a VM; async modules first | tags | | `--failed`, `--stale` (module dependencies) | 60 s per test | |

**Scheduling.**
* **Counted slots:** nextest's `threads-required`, CTest's `PROCESSORS` and `RESOURCE_GROUPS`, Bazel's `cpu:N`.
* **Named mutexes:** CTest's `RESOURCE_LOCK`, nextest's test groups, JUnit's `@ResourceLock` with read and write modes.
* **Exclusive tests:**
  - Bazel and GHC run them after everything else.
  - Meson drains what is running, runs the test alone, then goes on in order of priority.
* **Load caps:** CTest's `--test-load` and ninja's `-l`.
* **Memory** is a scheduled quantity only in Bazel's sizes and in CTest's generic resources.
* **Order by recorded history:** lit (failed first, then slowest), CTest (failed first, then cost within levels of dependency), HOL4 (critical path), stestr (LPT across workers).
* **ninja does not.** Its critical-path scheduler, despite the 1.12 release note, weighs every edge 1 in every release to 1.13.2. Weighting by recorded durations is merged on master and unreleased.

**Agents.** Several runners print less when an agent runs them, detected by
the environment (`AI_AGENT`, `CLAUDECODE`, `CODEX_SANDBOX`, `CURSOR_AGENT`,
`GEMINI_CLI`, …):
* **Vitest 4.1's** `agent` reporter;
* **Jest 30.3's** `AgentReporter`;
* **Bun's** test runner;
* **V8's compiler harness,** which keeps the failures and the count, and prints one line saying what it left out, "so that the missing output isn't mistaken for a broken run".

Advice on a harness for agents:
* **Anthropic's account of a C compiler built by parallel agents:** "At most, it should print a few lines of output and log all important information to a file". `ERROR` and the reason go on one line, so that `grep` finds them.
* **Claude Code** shows a failing command's output as its head and tail. A runner should therefore put its summary and the path of its log at both ends.

### What Rune takes

| From | What | Where |
|---|---|---|
| Tasty, HUnit, SMLUnit | the tree as a value, listable without running | D2 |
| HSpec | `describe`/`it`; `/` paths; a ready rerun command; the seed kept with a failure | D2, D4, D5, D14 |
| SMLUnit, Alcotest | equality and printer passed explicitly | `EXPECT` |
| Poly/ML, QCheck/SML, MLton | a directory of programs as the tests, `Succeed`/`Fail` as `tests/lang`/`tests/errors` | D6 |
| GHC, Meson, compiletest | ways, with timeout multipliers; at the quick tier, one way | D7, D22 |
| GHC, DejaGnu, lit | strict expected failures; a separate verdict for a broken harness (ERROR); a non-strict "fragile" | D16, D19 |
| SML/NJ, compiletest | a known bug pins its output, so a fix shows | D16 |
| nextest, Bazel, CTest, Meson | processes in groups killed with TERM, a grace period, then KILL; job objects on Windows | D11 |
| pytest-xdist, OUnit | workers restarted after a crash | D9 |
| HOL4 | inactivity as the sign of a hung worker; critical path from recorded costs, with a seed that is complete or absent | D9, D12, D13 |
| CTest, lit | failed first; costs learned from passing runs only | D12, D13 |
| CTest, JUnit, nextest | counted resources and named mutexes | D12 |
| Meson | an exclusive test drains the slots and runs alone, in its place | D12 |
| CTest, ninja | a cap on the load | D12 |
| nextest, Bazel | FLAKY and LEAK verdicts; JUnit's `flakyFailure` | D14, D17 |
| pytest, Autotest, SML/NJ | only failures' directories kept | D15 |
| tasty-golden, GHC, compiletest | one `--accept`, never on an expected failure | D6 |
| lit, compiletest, GHC | declared requirements, skipped with a reason | D18 |
| V8, Vitest, Jest | a short report when an agent is detected, saying what it left out | D14 |
| Automake, Meson | 77 skip, 99 hard error | D19 |

**What none of them has:**
* the counts as an oracle, which GHC's allocation metrics come nearest to;
* a doctor that probes what the selected tests declare, which lit's feature list and GCC's cached probes come nearest to.

Rune's budgets (`tests/perf/*.budget`) and its doctor are the precedents.

## The experiments

**How they were run.**
* Everything ran on this machine: WSL2, 16 CPUs, 31 GB, of which about 15 GB was free. The owner's editor kept about one CPU busy throughout.
* The tree was a snapshot of `34b2b4c5` made with `git archive`, at `.worktrees/ut-measure`, built once: `make host-builds vm boot runedoc runeopt`, 247 s wall, 622 s user, 55 s system, 2.9 GB at the peak.
* Every timed run took the machine's lock, which it shares with the performance roadmap's measurements, and waited for the load to fall below 2. That roadmap's untimed jobs did not take the lock, and ran beside E1 to E9 in two slots, about 5 CPUs on average.
* The load and the CPU's counters were sampled once a second beside each run.
* The raw results are kept outside the tree, with the command and the machine's state for each.

### E1. `make check`, step by step

* **Method.** `make check MAKE=timemake.sh` on the fresh build. E2's run, with its logging wrappers, is the second sample. Its steps took 0.7 to 1.2 times the wall time of these and 0.8 to 1.4 times the CPU: the wrappers add a few milliseconds to each call, which shows in steps of many small calls, and the other work on the machine varied.
  - The wrapper times each of the 32 steps with `/usr/bin/time` (wall, user, system, the largest process's peak), and takes the size of `tests/out` before and after.
  - A sampler reads `/proc/stat`, the run queue and the available memory once a second.

**Results** (2026-10-11, the first run, on the fresh build). Every step passed.
* **Totals:** 56.4 minutes of wall time and 12,355 s of CPU (3.4 CPU-hours).
* **The machine was not quiet.** The performance roadmap's measurements ran in two slots beside it, and the owner's editor used about one CPU. The machine was 9.1 CPUs busy on average while `make check` itself used 3.65.
  * The wall times are therefore inflated, and the 15 minutes AGENTS.md gives for a quiet machine is the better figure for the total.
  * The CPU times, each step's own parallelism (its CPU over its wall time) and the disk do not depend on that.

| Step | Wall (s) | CPU (s) | Own CPUs | Added to `tests/out` |
|---|---|---|---|---|
| test-gc | 560 | 1,925 | 3.4 | 25 MB, 14,220 files |
| test-native | 552 | 759 | 1.4 | 482 MB |
| test-all | 515 | 781 | 1.5 | |
| test-laws | 338 | 807 | 2.4 | 44 MB |
| check-cross, check-docs, check-isa | 201 | 2,065 | 10.3 | 549 MB |
| check-units | 190 | 1,953 | 10.3 | 453 MB, 44,434 files |
| test-heap | 158 | 631 | 4.0 | 12 MB |
| test-register-jit | 137 | 700 | 5.1 | 88 MB |
| test-register | 87 | 592 | 6.8 | 63 MB |
| test-ir, check-levels | 82 | 964 | 11.8 | 38 MB |
| test-incremental | 81 | 91 | 1.1 | 14 MB |
| check-reproducible | 70 | 73 | 1.0 | 61 MB |
| check-layouts | 66 | 129 | 2.0 | |
| check-heapsim | 59 | 61 | 1.0 | 181 MB |
| test-basis | 53 | 333 | 6.3 | 37 MB |
| test-lib | 44 | 41 | 0.9 | 6 MB |
| the REPL and IDE group | 37 | 60 | 1.6 | 53 MB |
| test bootstrap | 27 | 121 | 4.5 | |
| the other 14 steps | 112 | 271 | | |

* **What the table says:**
  - **Serial steps.** Eighteen of the 32 steps use one CPU or not much more: `test-doc`, `test-lib`, `test-incremental`, `test-deps`, `test-dynamic`, `test-build`, `test-install`, `check-reproducible`, `test-serve`, the REPL and IDE group, the census, the two simulators, `check-gcbench`, `perf-check` and `bench-smoke`, and in large part `test-native` and `test-all`. While they run, the other fifteen CPUs wait for the next step.
  - **The whole run.** On average `make check` kept 3.65 of its 16 CPUs busy (23%).
  - **Sampled each second:** the machine had fewer than eight CPUs busy in 48% of the seconds, and more runnable processes than CPUs in 33%, where steps that name several goals and the other session overlapped.
  - **Disk:** a fresh `make check` left 2.7 GB and 121,640 files in `tests/out`.

### E2 and E3. Every call, and the duplicates

* **Method.** Every executable of the snapshot's `bin/` was replaced by a wrapper that logs each call: the arguments, the directory, the times, the peak memory and a checksum of the program it runs. Then `make check` ran a third time.
  - **Compiles** are grouped by the compiler, its flags and the committed sources they read; generated sources, under `tests/out` or the incremental scenarios, are never counted as duplicates.
  - **Runs** are grouped by the VM, its flags, the program's checksum and its arguments.
  - A call is a duplicate when an earlier call in the same run had its key.

**What was logged.** E2 ran in two parts.
* **The first half.** `make check` up to `test-install`, which copies `bin/` and so cannot pass while `bin/` holds the wrappers.
* **E2b.** The later steps, one by one, stopped after two hours in `test-heap`. The wrappers made the register and JIT steps ten times slower: each call forks `date`, `mktemp`, `cksum` and `time` beside the VM.
  - And two REPL processes, left behind by the REPL group's failure under the wrappers, spun at 32% of a CPU each for 95 minutes until they were killed by hand. Nothing in today's harness stops what a failed test leaves behind (D11).
* **What is in the log.** 28,338 calls with 5,315 s of CPU: 69% of the CPU of the steps they span, and 41% of E1's total.
* **What is not:**
  - the SML/NJ builds, which run as heap images and not as executables in `bin/`;
  - the Python, the C compilers and the shell around the calls;
  - `test-gc`, the rest of `test-heap`, and the steps after it.

**E3, the duplicates:**

| | Calls | CPU | Repeated calls | Their CPU |
|---|---|---|---|---|
| compiles | 13,440 | 4,309 s | 4,596 (34%) | 977 s |
| runs | 14,898 | 1,006 s | 5,761 (39%) | 79 s |

* **Repeats that are the test.** 311 s of the repeated CPU is meant: `check-units` builds again warm and cached to test the cache, and `check-reproducible` builds the compiler again to compare the bytes.
* **Repeats that are not.** 745 s could go. The largest are in `test-register-jit` (253 s), `test-native` (238 s) and the part of `test-heap` that ran (186 s).
* **Counted from the Makefile, for the whole of `make check`:**
  - `run-tests.sh` is called 25 times: `test` once, `test-all` six times, `test-heap` four, `test-gc` nine, `test-register` once, `test-register-jit` twice, `test-native` twice.
  - Each call compiles the 351 programs: 8,775 compiles. The stack compiler compiles in 6 of the calls and `bin/rune` in 13.
  - So 5,967 compiles (68%) repeat one with the same compiler and flags. At the means measured here (0.41 s for the stack target, 0.24 s for the register target), that is about 1,740 s of CPU, 14% of `make check`'s.

### E4. One schedule instead of 32 steps

* **Method.** The calls of E2, with their measured durations, scheduled again by list scheduling on 16 simulated CPUs:
  - inside each step, as today;
  - as one global schedule, first in, first out;
  - longest first;
  - by critical path over the compile-to-run edges;
  - again without E3's duplicates.
* The bounds are the CPU time over 16 and the longest chain.
* The model has limits. The calls are the compilers and the VMs; the shell, `cmp`, Python and C compilers in between are not in it, and the log covers 41% of E1's CPU (above).

| Schedule of the logged calls, 16 CPUs | Makespan |
|---|---|
| the steps in sequence, longest first inside each step (kinder than today's file order) | 766 s |
| one schedule, first in, first out | 636 s |
| one schedule, longest first, or critical path first | 579 s |
| the same, without the repeats that are not the test | 415 s |
| the same, without any repeat | 389 s |
| bound: CPU / 16 | 579 s |
| bound: the longest chain (one law program, `MONO_ARRAY2`, one process) | 137 s |

* **The barriers.** One schedule removes the barriers between steps. It costs a quarter less than the steps in sequence, even though each step was given the best order inside it, and it reaches the CPU bound.
* **The CPU is the bound,** not the critical path. The longest chain is a quarter of the CPU bound. So the next gain is less work: the repeats that are not the test take 28% off what remains.
* **On an idle machine.** E1's 12,355 s of CPU over 16 CPUs is 12.9 minutes, near AGENTS.md's quarter of an hour. On an idle machine `make check` may already be near its CPU bound, and the gain there is the work removed. On a shared machine, as here, the steps left half the CPUs idle, and the schedule recovers them.
* **A baseline.** Both cases want an idle baseline. M3 measures one first.

### E5. What isolation costs

| What | Cost |
|---|---|
| an in-process call | about 1 µs |
| `fork` and `waitpid` of a Rune process with 10 MB live | 0.70 ms |
| the same with 100 MB live | 4.19 ms |
| starting the VM on a small compiled program, running it and reaping it | 1.15 ms (`runevm` and `runevm-stack` alike) |
| compiling the prototype's suite (`lib/json`, `lib/digest`, `lib/test/property`, about 300 lines) from source | 1.03 s |
| the same through the unit cache, cold and warm | 2.82 s and 1.02 s |
| the worker running 324 in-process tests | 0.35 s in all, about 1 ms a test |

* **What isolation costs.** A process per test costs a millisecond or a few, which is nothing beside a program that compiles for 0.1 s and more. For the Basis suite's 139,000 checks it would be minutes: that is where in-process checks in a worker pay.
* **Compiling a suite.** At this size the cache gains nothing over compiling from source, since most of the time is the Basis's units read either way. A suite is compiled once per run, and its programs are few (D10).

### E6. The disk

After E1's fresh `make check`, every test passed, and `tests/out` held 2.70 GB in 121,640 files.

| Directory | MB | What |
|---|---|---|
| `opt` | 538 | native code of every program, from `test-opt` and `test-native` |
| `opt-cache` | 426 | runeopt's translations, by checksum: a cache |
| `cross` | 366 | the bytecode of 528 programs from seven builds (`check-cross`) |
| `units`, `units-stack` | 446 | `check-units`' builds; 44,434 files |
| `matrix` | 165 | the Basis suite's programs, outputs and reports |
| `opt-cross` | 151 | the seven builds of runeopt |
| `census-validate`, `heapsim`, `gcsim` | 201 | the simulators' traces |
| `reproducible` | 61 | eleven builds of the compiler |
| `laws` | 44 | law programs and results |
| the other 30 directories and 1,593 loose files | 302 | |

* **What a retention policy would delete.** Apart from `opt-cache`, everything is the output of jobs that passed, about 2.27 GB of the 2.70. Under D15 it would be removed as each job passed, leaving the caches, the reports and the history.
* **Why the main tree holds 7.4 GB.** Directories accumulate: hand-run tools, configurations that were renamed, and benchmark runs, none of which a run removes.

### E7. Flaky tests

* **Locally:** both runs of `make check` passed every step, on a loaded machine (E1, E2).
* **In CI:** the repository's GitHub Actions history (`gh run list`, 168 runs, 2026-09-14 to 2026-10-11) has 14 failed runs.
  * Nine of them failed on a commit that passed, unchanged, on another run.
  * **`bench-smoke`, four runs.** `mktemp` failed because `tests/out/benchmarks` did not exist on a fresh checkout. The script relied on an earlier step having made the directory: an order dependence through the shared `tests/out`. `99fb49bb` fixed it by hand.
  * **`test-basis`, one run.** `Posix.Signal.pipe/ends-shell` got exit status 7 instead of death by SIGPIPE, because the CI's shell passed an ignored SIGPIPE down to the test. `check.yml` now runs `make check` under `env --default-signal=PIPE`.
  * **`test-doc`, four runs, on four commits.** `lawerrors.lib.diag` differed from its expected file, and the same commit passed when run again. The cause was not established here; a diagnostic that depends on an order (a directory's listing, a hash table's) is the likeliest kind.
* **What it adds up to:**
  - About one CI run in nineteen failed for something other than the code.
  - Two of the three causes, a directory that another step makes and a signal disposition inherited from outside, cannot happen in a job with a directory of its own and dispositions reset (D11).
  - The third is what a FLAKY verdict with a record of each attempt would have caught, and named, at its first occurrence (D17).

### E8. More CPUs

`tests/run-tests.sh` with the stack VM (351 programs), at six job counts, on the loaded machine:

| `-j` | 4 | 8 | 12 | 16 | 24 | 32 |
|---|---|---|---|---|---|---|
| wall (s) | 23.2 | 16.5 | 16.7 | 15.1 | 14.2 | 13.4 |
| CPU (s) | 70 | 88 | 113 | 113 | 106 | 109 |

* **Past eight jobs** the wall time hardly moves, and the CPU time grows.
* **The tail.** The suite's slowest program, `tests/errors/err.ty_astra-inference-limit.sml`, starts last because the errors come after the language tests in file order. It sets the end of the run.
* **The CPU time.** Beyond eight jobs it buys contention, on a machine of 16 logical CPUs that other work shared.
* **The largest process** peaked at about 600 MB.
* **For D12.** The order matters more than the count of slots, and memory is no constraint for these jobs.

### E9. The prototype

The prototype (`proto/` in the drafts; 937 lines of SML in four files) is:
* the tree, the filter language and soft checks;
* a supervisor: fork, a new process group, a fixed-width directory shaped like the root, `dup2` of the streams to files, `exece` with an environment list, `waitpid_nh`, the deltas of `times ()`, TERM then KILL, a cap on output by file size, and leftover processes found by signalling the group;
* a scheduler (critical path, CPUs, memory and pools);
* `tests/lang` and `tests/errors` as compile, run and restore jobs with run-tests.sh's verdicts, compiled once per compiler and run in several ways;
* an in-process suite as a worker that the runner restarts after a crash;
* events in JSON lines, retention, a history of durations, `--resume`, and output for a terminal or a log.

**Planted faults.** Every fault was reported with its cause, and the control test passed.
* In `tests/lang`, through the forking supervisor, the faults and their reports were:
  - a wrong `.expected` file: "stdout differs, line 1: expected "2", got "1"";
  - an endless loop: timeout after 5 s, with the group killed;
  - a SIGSEGV: signal 11;
  - an output flood: the output cap. Polled every 50 ms, the 50 MB cap let 66 MB through, so a hard cap needs `RLIMIT_FSIZE` (G4);
  - a memory hog under a 1 GB limit: "runevm: out of memory";
  - a forked grandchild left behind: "passed, but left processes behind".
* In the in-process worker, among 64 tests, the faults were a failed check, an exception, an endless loop (stopped after its 10 s per-test limit) and a SIGSEGV. The worker was restarted twice, and the test after the faults ran.

**Against `run-tests.sh`.** `tests/lang` and `tests/errors` in three ways, on the snapshot:
* the stack VM, as `make test` calls it;
* the register VM with the throughput collector and with the low-pause collector, verified, as `make test-gc` calls it.

`run-tests.sh` ran three times in a row, as the Makefile calls it; the prototype ran once, at 16 slots.

| | `run-tests.sh` × 3 | the prototype |
|---|---|---|
| verdicts | 351 + 351 + 351 passed | 982 passed (280 × 3 programs and 71 × 2 error tests, one per compiler) |
| compiles | 1,053 | 702 |
| wall | 137.8 s (13.1 + 41.5 + 83.2) | 93.6 s |
| CPU | 481 s | 404 s, of which the runner's own 8.5 s |

* **Verdicts.** Every test kept its verdict, run from a directory of fixed width shaped like the root (*The run*).
* **Compiles.** Sharing them saved a third of the compiles and 16% of the CPU.
* **The wall time** is set by one test: `rt.gc_stress` with the low-pause collector ran 77.5 s by itself, in both runners.
  - The prototype had no history on its first run, so it could not start that test first. With history it would, and the run would take about as long as that one test and its compile.
  - The prototype's 93.6 s is within 20% of that bound. `run-tests.sh` in its three calls took 47% longer, mostly because the long test of each call runs alone at the call's end.
* **The runner's cost.** It spent 8.5 s of CPU on 1,566 jobs, about 5 ms a job, mostly forking itself. A spawn that does not copy the runner (G4) makes that smaller.

### E10. The census

E10 is *Where we are*'s table and *Appendix A*.

### E11 and E12

**E11, selection replayed.**
* **Method.** The 470 commits on master's history (2026-09-14 to 2026-10-11, merges left out), each mapped to the groups of tests that D22's map would select for the files it changed.
  - Everything is selected by `src/` (but `src/doc` and `src/opt`), `runtime/`, `lib/basis/`, the Makefile and the build files.
  - A library selects its own suite and its users'.
  - `docs/plans/` and other prose select only the documentation's checks.
  - A suite's own files select that suite.

| Commits | Share | What they would select |
|---|---|---|
| 313 | 66.6% | everything |
| 92 | 19.6% | prose only: no test, or the documentation's checks |
| 25 | 5.3% | only the suites whose tests they changed |
| 40 | 8.5% | a few groups: scripts, benchmarks, a library, runedoc, tools |

* **What it says.** Selection by files saves the whole run on a third of the commits, and nothing on two thirds. It is worth having for the prose and the tests. The schedule (D12, D21) is what makes the other two thirds cheaper.
* **A caveat.** These are commits. An agent's iterations between commits are not in the history; they are what `--affected` and the profiles serve.

**E12** was not done. How much of an agent's time goes into tests is not recorded anywhere this roadmap could read.

## Constraints

What the design must keep, from the repository's rules and its documents:

* **Every commit is green.** `make check` passes at every commit, on every host's build of the compiler and on the compiler's own (AGENTS.md). A migration is many small green commits, never a red tree.
* **The oracles stay what they are.** Output against reviewed files, exact counts, and bytes that reproduce (`docs/testing.md`). A runner adds no tolerance, and never accepts generated output for a person: "`.expected` files are written by hand or reviewed line by line" (AGENTS.md).
* **The harness's rules** (`docs/testing.md`, *Rules for a harness*):
  - the same three streams for both sides of a comparison;
  - a fixed directory and name;
  - counts compared as text;
  - `timeout` and `ulimit -v` around experimental VMs;
  - counts may be taken under load, times may not.
* **Libraries:**
  - a library beside the Basis has a `library.build`, a generated MANIFEST, documented signatures, runedoc pages and tests in `tests/lib`;
  - it builds on every host where its files say `host yes`;
  - it never works around another compiler's bug: the failure is a `HOST-BUG` line and a report in `docs/bugreport/HOST`;
  - it uses no `_prim` (AGENTS.md; the owner, 2026-09-27 and 2026-10-10).
* **The runtime:** a primitive that asks the operating system goes behind `runtime/sys/sys.h` in three layers and is written on the hosts (`tests/basis/host/rune-prim.sml`). A structure that is not the specification's is an extension, with its rows in `docs/language.md`.
* **The default VM:** the register VM with its JIT is the default for every operation, and the stack VM is for differential testing (the owner, 2026-10-09).
* **runedoc reads the Basis suite.** `DocTests` parses the suite's calls of `T` for `Pinned by:` and `--check-coverage` (`src/doc/doctests.sml`). `T`'s calls keep their shape.
* **The machine is shared.** Other agents and the owner's editor use it. Every process that may pass a gigabyte runs under `ulimit -v`, heavy jobs run one at a time, and processes are killed by number, never by pattern (`docs/testing.md`; the measurements here took the machine's lock with the performance roadmap's).
* **CI:** `make check` runs on every pull request on Ubuntu 24.04 (`.github/workflows/check.yml`), without tmux, Windows, qemu or a second machine.

## The architecture

This is the architecture as the owner decided it on 2026-10-12, every
recommendation taken. Each part is argued, against its alternatives, in
*Decisions*.

### The layers

| Layer | Where | What |
|---|---|---|
| The core | `lib/test/unit`, portable (`host yes`), written on `lib/test/property` | the tree of tests (`TEST`), checks (`EXPECT`), golden files (`GOLDEN`), properties as tests, a suite's `main` with plain and event output (`SUITE`, `Suite`) |
| The runner | `lib/test/runner`, Rune-only (`host=no`), written on the core, `lib/json` and `lib/terminal` | jobs and steps, ways, the supervisor, the scheduler, records and history, retention, the display, expectations, requirements and the doctor, the command line |
| The inventory | `tests/**/suite.sml`, listed in `tests/test.build` | each area's tests as a value; `bin/rune-test` is the runner compiled with them, by make |

The split follows `lib/test/property` and `lib/test/property/basis`. What
every compiler can build is below, and what needs Rune is above. A
library's tests written on the core run on the five other compilers in
`make test-lib-hosts`, as they do today (D1).

### The tree

Tests are values. A suite is a structure that ascribes a signature and
exports a tree. That tree can be listed, filtered and checked for what it
needs before anything runs (D2):

```sml
signature TEST =
sig
  type 'a tree                        (* tests whose leaves are 'a *)
  type test = (unit -> unit) tree     (* in-process tests *)
  val it : string -> 'a -> 'a tree
  val describe : string -> 'a tree list -> 'a tree
  val property : string -> (unit -> Prop.prop) -> test
  val golden : string -> {expected : string, actual : unit -> string} -> test
  val tag : string -> 'a tree -> 'a tree
  val timeout : Time.time -> 'a tree -> 'a tree
  val requires : string list -> 'a tree -> 'a tree      (* capabilities, D18 *)
  val resources : {cpus : int, memory : int} -> 'a tree -> 'a tree
  val pending : string -> 'a tree -> 'a tree            (* listed, not run, with the reason *)
  val ways : (string * 'w) list -> ('w -> 'a) tree -> 'a tree
  val leaves : 'a tree -> {path : string, tags : string list, meta : meta, leaf : 'a} list
end

signature EXPECT =
sig
  exception Failure of string
  val that : string * bool -> unit                       (* a soft check *)
  val eq : (''a -> string) -> string * ''a * (unit -> ''a) -> unit
  val equal : ('a * 'a -> bool) * ('a -> string) -> string * 'a * (unit -> 'a) -> unit
  val raises : string * (exn -> bool) * (unit -> 'a) -> unit
  val fail : string -> 'a                                (* stops the test *)
end

signature SUITE = sig val name : string val tests : Test.test end
functor Main (S : SUITE) : sig val main : unit -> unit end
```

* **The hierarchy is the paths.** The brief's "library test set containing the basis library test set containing the Word64 test set" is the tree `lib/basis/word64`, and every filter, exclusion and resume speaks in such paths (D4).
* **The leaf is a type parameter.** The core's leaves are closures. The runner's are job descriptions (*Jobs, steps and ways*). Listing, filtering and metadata are written once, for both (D2).
* **A test is the unit of scheduling and of verdict.** Inside it, `Expect.that` and its kin are soft checks: a test fails if any check failed, and each failed check is reported with its label. The Basis suite's `T` (`tests/basis/harness.sml`) becomes such a test per program, with its 139,000 checks inside, and keeps its call shapes, which runedoc reads (`src/doc/doctests.sml:1-18`) (D3).
* **Properties are tests.** `Test.property` runs `Check.check` with the runner's settings. A failure carries the shrunk counterexample and the replay token, and the runner's history keeps the token to try first next time (D5).
* **The suite's `main`** is a small protocol (D10):
  * `--list` prints the paths;
  * `--run PATHS` and `--after PATH` run;
  * `--events FILE` writes `start` and `end` events, each line flushed, so that a runner whose worker died knows which test it died in;
  * without options it runs everything and prints `PASS`/`FAIL` lines, as the libraries' tests do today. The hosts can run it that way.

### Jobs, steps and ways

Most of Rune's tests compile a program, run it and compare what it printed.
In the runner such a test is a small graph of **steps** (D8):

* `Compile {compiler, flags, sources, output}`;
* `Run {argv, stdin, vmFlags, limits}`;
* `Compare {kind, expected, actual}`, where the kind is exact, the first line, a substring, counts equal, or bytes equal;
* `Worker {suite, paths}`, an in-process suite;
* `Command {argv}`, the foundational scripts that stay (D23).

* **Steps are shared by key.** A step's key is its tool (the binary's identity), its flags and the digests of its inputs, and steps with the same key run once per run. That is how `test-gc`'s four runs of `run-tests.sh`, which compile every program four times into two different bytecodes, compile each program twice (E3).
* **Ways.** A **way** is a named configuration: the compiler, the VM and its flags, the environment, a timeout multiplier, and resources. Examples are `stack`, `register`, `jit-all`, `gc-low-pause`, `stress`, `asan`, `linux32`, `ppc64`, `windows` and `native`.
  * `Test.ways` makes every leaf of a subtree once per way, named `NAME[way]`.
  * The wrapper VMs that the Makefile writes into `bin/` today (`bin/runevm-gc-*`, `bin/runevm-stress`, ...) become way records (D7).
* **Make builds, the runner tests.** A step never builds a tool. The runner is started on a tree that make has built, and it says which tools it needs (D8, D21).

### The run

`rune-test run` is one process and one loop (D9, D11):
1. start every ready job that fits (*The scheduler*);
2. reap whatever ended (`waitpid_nh`);
3. look at the clock for timeouts, and at the output files for their caps;
4. redraw the status, at most ten times a second;
5. sleep a couple of milliseconds when nothing happened.

**How a job runs.**
* A job is a process in a group of its own, in a directory of its own.
* Its environment is a fixed list: `PATH`, `HOME`, the suites' fixed `TZ`, and nothing that forces colour.
* Its standard input is `/dev/null` or the test's `.stdin`. Its output and errors go straight to files, so a crash leaves them on disk and nothing needs to read a pipe.

**Directories.**
* A job's directory has a fixed width (`tests/out/r/<run>/j/00042/`). It is shaped like the root of the tree where a test expects one: a `tests/out/`, a link to the sources' directory, and the program under the name it has today.
* So paths, and with them the counts, do not change.
* When a job fails, its directory is kept and named after the test (`tests/out/r/<run>/failed/lang/basis.int_ops[stack]/`). When it passes, the directory is removed at once (D15).

**Ending a job.**
* A timeout sends TERM to the group, and KILL two seconds later. An output cap ends the job in the same way.
* When the group outlives its leader, the leftover processes are killed and the test is reported as leaking them, as nextest does.
* Ctrl-C (`Runtime.catchInterrupt`) kills the running groups, writes what is known, and leaves a run that `--resume` continues.

**Workers.** An in-process suite runs as a worker job, which writes its events to a file. The runner restarts a worker that crashes, or that has stayed in one test longer than that test's timeout, after the test it died in. The test is reported as `CRASH` or `TIMEOUT`, with the worker's output kept (D9).

### The scheduler

Admission is pure: a function of the ready jobs, the free resources and the
history. It is tested with properties on a simulated clock (D12).

* **Resources:**
  * CPUs: 1 by default; a compiler run with `-j` declares more;
  * memory in MB, learned from each job's recorded peak;
  * pools: `exclusive` (timing jobs, MLton built by Rune at about 11 GB), `windows-interop:k`, `qemu:k`, and named mutexes.
* **Priority:**
  * the critical path: the longest chain of recorded durations from a job to the end of the run;
  * longest first (LPT) where there are no edges;
  * a job that failed last time goes first, as CTest and lit order them.
* **Load:** the number of slots is the processors minus the load from outside the run, read from `/proc/loadavg`. This machine is shared with other agents and with the owner's editor.
* **Exclusive jobs** wait until the slots drain, and no new small job starts in front of them once they are next.

### Verdicts

Each verdict and whether it fails the run:

| Verdict | Meaning | Fails the run |
|---|---|---|
| PASS | | no |
| FAIL | the test's oracle said no | yes |
| ERROR | the harness, not the test: a missing capability in `check`, a step that could not start, a worker that would not come back | yes |
| TIMEOUT | the test's time ran out | yes, even when the test is expected to fail |
| CRASH | a signal, or a worker that died in the test | yes |
| LEAK | processes left behind | yes |
| XFAIL | failed, and was expected to | no |
| XPASS | passed, and was expected to fail: the expectation is stale | yes |
| FLAKY | failed, then passed on a declared retry | no; listed |
| SKIP | not run, with its reason | no |

Most of these follow DejaGnu's and lit's lists. TIMEOUT staying a failure
under an expectation is lit's and CTest's rule.

### Records and history

* **Per job:**
  * the wall time on a monotonic clock (G1);
  * user and system time (G2; meanwhile the deltas of `times()` across each reap);
  * peak memory (G2);
  * the bytes of standard output, standard error and the job's directory;
  * the exit status or the signal;
  * the counts, where the job printed a `--count` line.
* **Per run:** the commit and whether the tree was dirty, the machine, the processors, the load at the start and the end, the ways, and the tier or filter.
* **Where they go:**
  * the run's records go to `events.jsonl` in the run directory, one line per event and written as it happens, so a run that dies half-way still says what it did;
  * `build/test-history.tsv` is derived from them at the end (`make clean` removes it; a fresh tree schedules by the committed seed `tests/durations.tsv`, which only a complete run writes): per path and way, the last durations, the 90th percentile, the peak memory, the last outcome, the number of flips and the last failing commit. It is what the scheduler, `--failed` and the flaky statistics read (D13).

### Output

The runner writes for the reader it has (D14).
* **On a terminal:** one status line drawn with `lib/terminal`'s `Style`: done and total, failures, running, the slowest running job, and an estimate of the time left. Each failure is printed above that line as it happens, and a summary comes at the end.
* **To a log or an agent:** nothing for a passing test; a line every 30 seconds saying the run is alive and how far it is; each failure as one block that stands alone; the summary. An agent, recognised by its environment, also gets the summary's first lines and the path of the events at the start, since it may see only the head and the tail of a long output.
* **Always:** the JSON-lines events, and a Markdown summary for CI.

A failure block:

```
FAIL lang/basis.int_ops[gc-low-pause]: stdout differs, line 14: expected "~3", got "3"
  kept:    tests/out/r/20261011-1832/failed/lang/basis.int_ops[gc-low-pause]/
  command: cd …/j/00412 && bin/runevm --gc low-pause --gc-verify … --checked tests/out/basis.int_ops.rbc < /dev/null
  rerun:   bin/rune-test run 'lang/basis.int_ops[gc-low-pause]'
```

The summary ends with one line, for example:

```
RESULT: FAIL 3 of 61,240 tests (2 FAIL, 1 TIMEOUT; 4 FLAKY passed, 12 XFAIL), 13 min 12 s wall,
        181 min CPU (86% of 16), slowest basis/real[ppc64] 64 s, kept 41 MB, freed 2.3 GB
```

### Expectations

One file format and one engine for every list that says a test is known to
fail, need not pass, or does not apply (D16):

```
# way-glob | path-glob[::check-label-glob] | CATEGORY | reason
native:polyml | basis/real::Real.fmt/* | HOST-BUG | Poly/ML rounds 0.5 to even in FIX (docs/bugreport/polyml/…)
*             | lang/rt.interrupt_self  | UNSUPPORTED | runeopt's code never polls for an interrupt
```

* **What each category means.** A strict expected failure (`HOST-BUG`, `RUNE-DEV`, `WIDTH`, ...) must fail: when it passes, the run fails and calls the line stale. A lenient one (`HOST-FLAKY`, `FLAKY`) may pass or fail. A skip (`HOST-ABSENT`, `UNSUPPORTED`, ...) is not run. A quarantine (`QUARANTINE until 2026-11-30`) runs and is reported, never fails the run, and becomes a stale line on the date it names.
* **Where the files are.** They stay where they are (`tests/basis/deviations.txt`, `law-skips.txt`, `tests/lib/deviations.txt`, and the skip files), in one format.

### Requirements and the doctor

A test names the software it needs as capabilities: `mlton`, `polyml`,
`tmux`, `qemu-ppc64`, `windows-interop`, `python3:jupyter_client`,
`cc-m32`, `gdb`. A capability is a value with a probe, a version pattern and
an install hint for each package manager (D18).

* `rune-test doctor FILTER` probes what the selected tests need, and only that.
* `rune-test run` treats a missing capability as an error in the `check` tier and as a skip, with its reason, elsewhere.
* `scripts/doctor.sh` keeps what must be known before anything is built: a C compiler and the hosts.

### The command line

```
rune-test list    [FILTER] [--json]                 the inventory; runs no test
rune-test doctor  [FILTER]                          probes the capabilities the selection needs
rune-test run     [FILTER] [--tier T | --profile P | --affected [REV]]
                  [-j N] [--failed] [--resume] [--from PATH] [--repeat N] [--until-fail]
                  [--keep] [--accept] [--format terminal|plain|json]
rune-test explain PATH                              commands, sidecars, expectations, requirements
rune-test stats   [--slowest | --flaky | --biggest]
```

* **Filters** are paths with globs (`lib/basis/word*`), `tag:T`, `way:W`, `needs:C`, `status:failed|flaky|new|slow` and `changed`, combined with `!`, `&`, `|` and parentheses (D4).
* **Exit codes:** 0 when every test passed or was expected to fail; 1 when one failed; 2 for a usage error; 125 when the tree was not built or a required capability is missing, so that `git bisect run` skips the commit (D19).

## What the runtime must add

A runner written in Rune needs nine things from the runtime that it does
not have or cannot reach (*Where we are*, *What the Basis offers*).

**The rules they follow.**
* Each primitive that asks the operating system goes behind a call of `runtime/sys/sys.h` that every layer answers (`sys_posix.c`, `sys_win.c`, `sys_none.c`, `ENOSYS` where there is nothing to do), and is written on the hosts in `tests/basis/host/rune-prim.sml`. It needs a row in `docs/language.md`, a test and a documented member (AGENTS.md).
* None belongs in a structure of the Basis's specification. They go in `Runtime`, and in one new structure for processes.

| | What | Today | The cheapest fix | Until then |
|---|---|---|---|---|
| G1 | a monotonic clock | `Time.now` is `gettimeofday` (µs, it jumps); a monotonic `sys_clock_ns` exists in C (`runtime/sys/sys_posix.c:106-108`) and nothing exposes it | `Runtime.clock : unit -> Time.time` over it | `Time.now` |
| G2 | a child's user and system time, and its peak memory | `Posix.ProcEnv.times` (10 ms ticks); no peak memory reaches SML (`runevm --stats` prints the VM's own, `RUNE_MEMSTAT=1`) | a reap that returns the child's usage: `wait4` on POSIX, `GetProcessTimes` and `GetProcessMemoryInfo` on Windows | deltas of `times ()` across each reap; peak memory unknown |
| G3 | the processors this process may use | none (`scripts/ncpus.sh` in the shell; `sysconf` knows no `NPROCESSORS`) | `Runtime.processors ()`: the affinity mask's count on POSIX, `GetActiveProcessorCount` on Windows | read `nproc`'s output |
| G4 | starting a process with a directory, a group and limits | `RuneRuntime.spawn` (`lib/basis/runtime.sml:208-216`) takes a path, arguments, an environment and three descriptors; programs cannot see it (`RUNTIME` does not name it) | a `Subprocess` structure: spawn with a directory, a new process group (a job object on Windows), resource limits (address space, CPU, file size, core 0) and default signal dispositions | `Posix.Process.fork`, then `setpgid`, `chdir`, `dup2` and `exece` in the child (the prototype); limits through `sh -c 'ulimit …; exec …'` |
| G5 | ending a process and everything it started | `Posix.Process.kill` with `K_GROUP`; Windows has no groups and kills one process | `Subprocess.kill` on G4's group or job | the group on POSIX; on Windows the process alone |
| G6 | waiting for a child with a deadline | `waitpid_nh` and polling | optional: a pidfd with `OS.IO.poll`, `WaitForMultipleObjects` | a poll loop that sleeps 1-20 ms |
| G7 | the machine's load and free memory | none | none needed on Linux: `/proc/loadavg` and `/proc/meminfo` are files | the files |
| G8 | a pseudo-terminal | none | `openpty`, and ConPTY on Windows; it lets the terminal tests leave tmux | `tests/terminal/term.py` as a step |
| G9 | a deadline for in-process code | none | a VM budget of instructions per call (quickcheck.md's D9, option C, "left for later") | the worker's restart (D9) |

M2 does G1 to G5. G6 to G9 are left for when they are wanted.

## Decisions

Each decision gives the options, what favours each, and the recommendation
it was written with. The owner decided all of them on 2026-10-12, each as
recommended:

| Decision | Decided |
|---|---|
| D1. Layers and names | B: a portable core `lib/test/unit` and a Rune-only `lib/test/runner` |
| D2. What a suite is | B: a tree of tests as a value, `describe`/`it` included |
| D3. Tests and checks | C: a test is the unit of verdict; soft checks inside it |
| D4. Paths and filters | C: paths, `[way]`, `::label`; a small filter language |
| D5. Properties | A: a property is a test; replay tokens kept |
| D6. Golden files | A: the sidecars kept; one `--accept` |
| D7. Ways | B: a combinator; the wrapper VMs become ways |
| D8. Steps and sharing | C: a small graph of steps, shared by key |
| D9. Isolation | C: processes for commands; in-process suites in a restartable worker |
| D10. A suite and the runner | A: one program per suite, with a small protocol |
| D11. A job's environment, limits and end | C: hermetic jobs with limits, timeouts by size |
| D12. The scheduler | C: CPUs, memory and pools; critical path first; a load cap |
| D13. Records and history | A: JSON lines per run, and a derived history |
| D14. Output | B and C: by reader; events always |
| D15. Retention | C: passing jobs removed at once; failures kept whole; caps |
| D16. Expectations | B: one format and one engine |
| D17. Flaky tests | C: retries only where declared; a FLAKY verdict |
| D18. Requirements and the doctor | B: declared capabilities, probed by `rune-test doctor` |
| D19. Modes | the list in D19 |
| D20. How the runner is built | A: by `$(RUNE)`, run on `bin/runevm`, with canaries |
| D21. `make check` | B: make builds, then one run of the runner |
| D22. Tiers and selection | A and B: tiers, profiles per kind of change, `--affected` |
| D23. Migration | B: suite by suite, with shadow runs and planted faults |
| D24. Windows | A: the runner drives the Windows VMs from Linux |

### D1. Layers and names

**Decided: B** (2026-10-12), as recommended.

* **A. One library, `lib/test/unit`, Rune-only.** It is the simplest. But the five other compilers could no longer run the libraries' tests (`make test-lib-hosts`), since every test would need what only Rune has.
* **B. A portable core and a Rune-only runner.** **Recommended.**
  - **`lib/test/unit`** (`host yes`): the tree, checks, golden files, properties as tests, and a suite's `main`. It is written on `lib/test/property`, for its printers and equalities (`Show`, the `eq` of an `'a arb`), so that a check and a law print a value the same way.
  - **`lib/test/runner`** (`host=no`): jobs, ways, the supervisor, the scheduler, records, retention, the display, expectations, requirements and the command line, on `lib/json` and `lib/terminal`.
  - **The inventory:** `tests/**/suite.sml`, compiled with the runner into `bin/rune-test`.
* **C. One library named `lib/test`, with `property` and `runner` below it.** Tidy, but `test` alone does not say what it is, and it mixes the portable with the Rune-only.
* **D. HSpec's name, `lib/test/spec`.** The library is less HSpec than its tree and filters suggest (D2), and "unit" is what the brief calls it.

B has the shape of `lib/test/property` and `lib/test/property/basis`, and
it follows the owner's rule that generic code becomes a library of its own
(AGENTS.md).

### D2. What a suite is

**Decided: B** (2026-10-12), as recommended.

* **A. Registration by side effect, as HSpec's `describe` and `it` build a spec in a monad.** It reads well. But the tree exists only while a program runs, and a global builder has to be emptied between suites.
* **B. A tree as a first-class value, as Tasty's `TestTree` and HUnit's `Test` are.** `describe` and `it` are names for building it. **Recommended.**
  - **Listed without running.** A value can be listed, filtered, tagged and asked what it needs before anything runs, which the brief's inventory and doctor modes require.
  - **Nothing hidden.** HSpec builds such a tree inside (its `SpecTree`). B shows it, with no global state.
  - **The leaf is a type parameter** (`'a tree`): closures in the core, job descriptions in the runner. Filters, listing and metadata are written once.
* **C. Flat registration by name, as Go, libtest and `ppx_inline_test` do.** Without reflection SML would need a generated list, and the hierarchy the brief asks for would live in the names only.
* **D. Catch2's sections, where a body runs again once per leaf.** It needs control over the body that SML gives only through callbacks, and a body that runs again is hard to reason about.

The brief's "test descriptions written against some signature" is B's
`SUITE`: a structure that ascribes it is a suite. A functor `Main` makes it a
program (D10).

### D3. Tests and checks

**Decided: C** (2026-10-12), as recommended.

* **A. One assertion per test, the first failure ends it, as in HUnit and HSpec.**
* **B. Many soft checks per program, as the Basis suite's `T`, GoogleTest's `EXPECT_*` and Go's `t.Error` do.**
* **C. Both.** A test is the unit of scheduling, filtering and verdict. Inside it, checks are soft and labelled, and `Expect.fail` ends the test. **Recommended.**
  - **Why not A.** The Basis suite has 139,269 checks in 230 programs (E1). They cannot be 139,269 scheduled units, and their labels must still be reported, filtered (`::label`) and printed as `PASS label` lines.
  - **Where a check is.** On Rune a failure can carry `Runtime.trace`'s frames through a hook. On the other compilers it carries its label alone.

### D4. Paths and filters

**Decided: C** (2026-10-12), as recommended.

* **A. Globs on paths, as HSpec's `--match` and GoogleTest's `--gtest_filter` do.**
* **B. Tags in boolean expressions, as pytest's `-m` and Bazel's `--test_tag_filters` do.**
* **C. Both, in one small language after nextest's filtersets.** **Recommended.**
  - **Atoms:** a glob on the path, `tag:`, `way:`, `needs:`, `status:failed|flaky|new|slow`, `changed`.
  - **Operators:** `!`, `&`, `|` and parentheses.
  - **Plain words:** a word without `*` or `?` matches as a substring, as `run-tests.sh`'s FILTER does today.
* **Paths:**
  - they are joined by `/` (`lib/basis/word64`);
  - a way is in brackets (`lang/basis.int_ops[gc-low-pause]`);
  - a check's label follows `::` (`basis/word64::Word64.fromInt/max`).

  None of these clashes with the Basis suite's labels, which use `.` and `/`, or with the laws' `@Int8`.
* **Order:** the order of the inventory is the order of declaration, the same on every run. That is what makes `--from PATH`, `--resume` and "the test the worker died in" mean something.

The prototype's parser is 30 lines (E9).

### D5. Properties

**Decided: A** (2026-10-12), as recommended.

* **A. A property is a test.** `Test.property name p` runs `Check.check` with the runner's settings: cases, seed, and the deep mode of `RUNE_PROPERTY_DEEP`. **Recommended.**
  - **Verdicts:** `Passed` is PASS; `Failed` is FAIL, with the shrunk counterexample and the replay token in the failure block; `GaveUp` is an ERROR.
  - **Replay tokens:** the runner's history keeps the token of every failure, and the next run tries it before anything else, as Hypothesis's example database and proptest's regression files do.
  - **Laws:** `Check.laws`' protocol (`RUNE_PROPERTY_ONLY`, `AT`, `AFTER`, `SKIP`, `REPLAY`, the `LAW` line printed before each law; `lib/test/property/check.sml:611-667`) is a filter, a resume and a restart after a crash, written by hand. The runner gives all three to every suite, so a law becomes a leaf like any other (M8).
* **B. Laws stay commands with their environment variables.** This keeps `tests/basis/run-laws.sh`'s watchdog and its restart loop, 205 lines (E10).

Seeds stay what quickcheck.md's D9 made them, hashes of the names, so a
failure is the same on every machine.

### D6. Golden files

**Decided: A** (2026-10-12), as recommended.

* **A. The sidecars as they are.** **Recommended.**
  - **Programs:** `.expected`, `.stderr`, `.stderr-head`, `.exitcode`, `.cwarn`, `.restore` and the rest become one kind of program test in the runner.
  - **Accepting output:** one option, `--accept FILTER`, replaces the seven `--update` modes (`run-tests.sh`, `run-doc-tests.sh`, `run-ir-tests.sh`, `diagnostics/run.sh`, `repl-protocol/run.py`, `run-perf.sh`, `run-mlton-bench.sh`), as tasty-golden's `--accept`, GHC's `make accept` and Rust's `--bless` do.
  - **Failures:** a failure shows where the output first differs, and keeps both files.
  - **Review:** AGENTS.md's rule stays: accepted output is reviewed line by line.
* **B. Expectations in the test file, as lit's `RUN:`/`CHECK:`, ocamltest's `(* TEST *)`, compiletest's `//~ ERROR` and `ppx_expect` keep them.** Worth considering later for `tests/errors`, where the expected first line could be a comment beside the error. Moving 468 files now is churn with no gain.
* **C. Cram transcripts, as Dune's cram tests and Mercurial's `.t` files are.** A candidate for the small command-line suites (`tests/deps`, `tests/buildfile`, `tests/dynamic`) in M10, whose scenarios are shell today.

### D7. Ways

**Decided: B** (2026-10-12), as recommended.

* **A. No axis.** Each configuration is written out, as the 30-odd calls of `run-tests.sh` in the Makefile are.
* **B. Ways as a combinator** (`Test.ways`). Every leaf of a subtree is made once per way. **Recommended.**
  - **Prior art:** GHC's testsuite ways, Meson's test setups, compiletest's revisions and lit's parameters.
  - **What a way is:** a record with a name, the compiler, the VM and its flags, the environment, a timeout multiplier and resources.
  - **Exceptions per way:** a leaf can opt out of a way, and an expectation can name one.
  - **Wrapper VMs** that the Makefile writes into `bin/` (`runevm-gc-*`, `runevm-stress`, `runevm-gcbits-stress`, ...) become way records.
* **C. Configurations at the top of the tree, as the matrix's are.** The same test appears under many roots, and nothing knows that two of them share a compile.

B removes the repetition and lets the steps of different ways share their
compiles (D8). A deviation that depends on the configuration then becomes a
filter on ways.

### D8. Steps and sharing

**Decided: C** (2026-10-12), as recommended.

* **A. Every test self-contained, compiling its own program in every way, as today.**
* **B. Fixtures with set-up and tear-down, as Tasty's `withResource`, pytest's scoped fixtures and CTest's `FIXTURES_*` provide.** Fixtures share a resource, but they share it by hand, and they do not see that two tests compile the same thing.
* **C. A small graph of steps.** **Recommended.**
  - **Steps:** a test is a few steps (compile, run, compare). A step declares its inputs and outputs, and steps with the same key are run once per run: the tool's identity, its flags and the digests of its inputs.
  - **What it removes.** 5,967 of the 8,775 compiles of `tests/lang` and `tests/errors` in a `make check` repeat one another: about 1,740 s of CPU, 14% of the whole (E3). It also turns a hidden order into an edge: `test-opt` and `test-native` read the `.rbc` files that earlier steps left in `tests/out` (`tests/opt/run-opt-tests.sh:139-142`).
  - **Limit:** make builds the tools, and the runner never rebuilds `bin/rune` (D21).

### D9. Isolation

**Decided: C** (2026-10-12), as recommended.

* **A. Everything in the runner's process.** Fast, and fragile: a segfault or a loop ends the run.
* **B. A process per test, as nextest, Criterion, Check's fork mode and Bazel do.** Robust, but costly. It means 139,269 checks as processes, or a fork per test on Windows, where fork is an emulation (about 30 ms plus 3-4 ms per MB of live heap, `docs/building.md:205-208`).
* **C. Both, chosen by kind.** **Recommended.**
  - **Command tests are processes:** the compile-run-compare tests, and the scripts that stay.
  - **In-process suites run in a worker**, itself a child of the runner, which writes its events to a file. If the worker crashes, or stays in one test past that test's timeout, the runner names the test it was in, marks it CRASH or TIMEOUT, and starts a new worker after it. This is pytest-xdist's worker restart, and the `LAW` line with `RUNE_PROPERTY_AFTER` generalised.
  - **A test or a group can ask to be `isolated`:** a process per test.

The prototype did this with planted faults: a loop stopped after its
timeout, a SIGSEGV, an exception and a failed check. The worker came back
after each, and ran the test after them (E9). A fork costs 0.7 to 4 ms, a
spawn of the VM about a millisecond, an in-process call a microsecond (E5).

### D10. A suite and the runner

**Decided: A** (2026-10-12), as recommended.

* **A. One program per suite, with a small protocol: `--list`, `--run PATHS`, `--after PATH`, `--events FILE`.** **Recommended.**
  - **Prior art:** this is the test binary of nextest and of Go.
  - **Events:** JSON lines (`start`, `check`, `end` with the verdict, times and message). Plain `PASS`/`FAIL` lines stay for people, the hosts and `DocTests`.
  - **It runs everywhere:** on the hosts as well, since a library's tests are such programs already. It needs no units, and a crash stays in its process.
  - **Compiling costs.** A suite's libraries come from the unit cache (`--units --cache-dir`, `docs/units.md`).
* **B. Plugins.** Suites are `_dynamic` units that one long-lived runner loads, and forks per test, as a zygote. Faster when many suites are small, but it needs `--units` everywhere and works on Rune only. Later, if ever: E5 found a suite's compile to take about a second.
* **C. One generated program of all suites**, as `runedoc --laws` generates law programs. One compile, but the largest program in the tree, and one bad suite stops all.
* **D. Descriptions as data**, as lit's `RUN:` lines are, with no SML. That is the scripts again.

TAP 14 and subunit v2 were considered for the protocol. JSON lines need no
new parser, since `lib/json` exists, and they carry the counts and the
labels.

### D11. A job's environment, limits and end

**Decided: C** (2026-10-12), as recommended.

* **A. As today:**
  - each job gets the environment it inherits;
  - six large runners have no timeout (`run-tests.sh`, `check-levels.sh`, `check-units.sh`, `check-cross.sh`, `check-register.sh`, `run-windows.sh`);
  - limits are a shell's `ulimit` in three places.
* **B. Hard timeouts by size, as Bazel's small, medium, large and enormous have.**
* **C. Hermetic jobs with limits.** **Recommended.**
  - **Environment:** a fixed list: `PATH`, `HOME`, the suites' `TZ`, and none of `FORCE_COLOR`, `CLICOLOR_FORCE` or `NO_COLOR`.
  - **Streams:** standard input from `/dev/null` or the `.stdin` file; output and errors to files.
  - **Directory:** one of fixed width, shaped like the root (*The run*).
  - **Process:** signal dispositions reset to their defaults, the SIGPIPE that `.github/workflows/check.yml` works around included. Core dumps are off. A new process group, or a job object on Windows.
  - **Limits:** the address space for experimental VMs, the size of a file, and a cap on output that the loop enforces.
  - **Timeouts:** a hard timeout by size or as declared, times the way's multiplier (qemu, Windows and stress are slower), as Meson's `--timeout-multiplier` does. A SLOW warning comes from history, as nextest's `slow-timeout` gives one.
  - **Ending:** TERM to the group, then KILL two seconds later.
* **Why C:** `docs/testing.md`'s rules (*Rules for a harness*), the counts that depend on a path's length, and the runners with no timeout at all. A socket test once hung on Windows for six hours.

The prototype ran with the environment cut to `PATH`, `HOME` and `TZ`, and
no test of `tests/lang` or `tests/errors` noticed (E9).

### D12. The scheduler

**Decided: C** (2026-10-12), as recommended.

* **A. Slots only, as `xargs -P` gives today.**
* **B. Slots plus named pools and mutexes:**
  - ninja's pools;
  - CTest's `RESOURCE_LOCK` and `RUN_SERIAL`;
  - JUnit 5's `@ResourceLock`;
  - nextest's test groups.
* **C. B plus quantities, priorities and a cap on load.** **Recommended.**
  - **Quantities:** CPUs per job (1 by default; a compiler run with `-j` declares more), and memory in MB, by size until the history has a peak for the job. Prior art: CTest's `PROCESSORS` and `RESOURCE_GROUPS`, Bazel's `cpu:N` tags, nextest's `threads-required`.
  - **Pools:**
    - `exclusive`, for timing jobs and MLton built by Rune at about 11 GB;
    - `windows-interop:k` and `qemu:k`;
    - mutexes, for legacy jobs that share a directory.
  - **Priority:** the critical path of recorded durations. Longest first where there are no edges, after Graham's LPT bound of 4/3 − 1/(3m). A job that failed last time goes first, as CTest and lit order them.
  - **Load:** the slots are the processors minus the load from outside the run, as GNU make's `-l` and CTest's `--test-load` do.
* **Why C:**
  - `make check` keeps 3.65 of its 16 CPUs busy on average (E1). Eighteen of its steps are serial, and the steps that name several goals oversubscribe the machine;
  - one global schedule of the logged calls would take 579 s against 766 s for the steps in sequence, even with each step ordered longest first (E4);
  - inside a step, the order matters more than the count of slots: `run-tests.sh` gains nothing past 8 jobs, because its slowest program starts last (E8, E9);
  - this machine is shared with other agents and with the owner's editor, and jobs of 11 GB and timing jobs must run alone.

The admission is a pure function, tested with properties on a simulated
clock (*Testing the tester*).

### D13. Records and history

**Decided: A** (2026-10-12), as recommended.

* **What is recorded, per job:**
  * the wall time on a monotonic clock (G1);
  * user and system time (G2), meanwhile the deltas of `Posix.ProcEnv.times`'s `cutime` and `cstime` across each reap, at the clock tick's resolution (10 ms);
  * peak memory (G2);
  * the bytes of standard output, standard error and the job's directory;
  * the exit status or the signal;
  * the counts, where the job printed a `--count` line.
* **What is recorded, per run:** the commit and whether the tree was dirty, the machine, the processors, the load at the start and at the end, the ways, and the tier.
* **Where they are kept:**
  * **A. JSON lines per run, and a history derived from them.** **Recommended.**
    - The run's events go to its directory as they happen.
    - At the end, a TSV in `build/` is rewritten from them: per path and way, the last durations, the 90th percentile, the peak memory, the last outcome, the flips and the last failing commit.
    - JSON lines survive a run that dies half-way, `lib/json` reads them, and the TSV is what the scheduler, `--failed` and the flaky statistics read.
    - **A fresh tree.** A committed seed of durations, `tests/durations.tsv`, covers a fresh tree and a new worktree. Only a run of every test may write it, as HOL4's generator requires: "a missing entry looks exactly like a cheap one". The local history overrides it.
  * **B. One growing TSV, as the matrix's `timings.tsv` is.** It holds durations, and nothing to rerun or diagnose by.
  * **C. Numbered subunit streams, as testrepository and stestr keep them.** It is a protocol nobody here reads.
  * **D. SQLite.** Rune has no binding to it.

### D14. Output

**Decided: B and C** (2026-10-12), as recommended.

* **A. One format for every reader.** People, logs, agents and CI need different things.
* **B. By reader.** **Recommended, with C.**
  - **On a terminal:** one status line through `lib/terminal`, redrawn at most ten times a second; the failures above it as they happen; a summary. `NO_COLOR` and `FORCE_COLOR` are obeyed as `Style.enabled` obeys them.
  - **To a log or an agent:**
    - nothing for a passing test;
    - a line every 30 seconds saying how far the run is, since an agent's tool call that sees no output for minutes may be cut off;
    - one block per failure that stands alone;
    - the summary, ending in one `RESULT:` line.
  - **A failure block holds:**
    - the verdict, the path and the way;
    - the reason: where the output first differs, the exception, or the signal or timeout with the end of the output;
    - where the full outputs are kept;
    - two commands: the runner's own rerun of that test, and the raw command line with its directory.
  - **Detecting an agent.** The runner takes the second form also on a terminal when the environment names an agent (`AI_AGENT`, `CLAUDECODE`, `CODEX_SANDBOX`, `CURSOR_AGENT`, `GEMINI_CLI`, …), as Vitest, Jest, Bun and V8's harness do.
  - **What the agent form adds:**
    - it says in one line what it leaves out, after V8's runner, so that silence is not taken for a broken run;
    - it puts the summary and the path of the run's events at the start of the output and again at the end, since Claude Code shows a failing command as its head and tail;
    - every failure line begins with its verdict, so `grep` finds them.
  - **Why so:** the cost of a log to an agent is its length, and the work is in the failures. A line per passing test, which every runner prints today (`passed 280, failed 0` aside), is thousands of lines that carry nothing. SWE-agent's interfaces found that concise feedback, with output capped and the relevant part shown first, helps a model (*What the literature says*).
* **C. Machine formats as well.**
  - The JSON-lines events, always.
  - A Markdown summary for `$GITHUB_STEP_SUMMARY`. It replaces the `tests/out/matrix/report.md` that each configuration overwrites, which is why CI's artefact after a failure holds only the last configuration's report.
  - JUnit XML later, for CI's annotations.

### D15. Retention

**Decided: C** (2026-10-12), as recommended.

* **A. Keep everything, as today.**
  - `tests/out` holds 7.4 GB in the main tree.
  - The matrix keeps 28 directories of configurations forever, some of them under names that no longer exist.
  - Every passing test of `run-tests.sh` keeps its bytecode and outputs.
  - The benchmark runs leave temporary directories that nothing removes.
* **B. Passing jobs' directories removed at once, failures kept whole, the last K runs kept.** This is pytest's `tmp_path_retention_policy = failed`, and Autotest's `testsuite.dir`.
* **C. B, with caps and accounting.** **Recommended.**
  - **Caps:** a cap on each job's output (the verdict OUTPUT-LIMIT), and a budget for all runs that evicts the oldest.
  - **Accounting:** the bytes written, reported per job and per run.
  - **Shared outputs** are counted by their users and removed after the last.
  - **Readable names:** a failed job's directory is moved to a name after its test.
  - **`--keep`** keeps everything.
  - **What it saves:** about 2.27 GB of the 2.70 GB that a fresh `make check` leaves, and 121,000 files (E6).

### D16. Expectations

**Decided: B** (2026-10-12), as recommended.

* **A. One list per area, each read by its own code**, as today:
  - `tests/basis/deviations.txt` (904 lines, nine categories);
  - `law-skips.txt` and `law-deviations.txt`;
  - `tests/lib/deviations.txt`;
  - `tests/opt-skip.txt`, `tests/windows-skip.txt` and `tests/portability-skip.txt`;
  - `tests/external/mlton-skip.txt`.
* **B. One format, and one engine with a meaning per category.** **Recommended.**
  - **The format** is `deviations.txt`'s, with a path in place of a label: `way-glob | path-glob[::label-glob] | CATEGORY | reason`.
  - **Strict expected failures** (`RUNE-DEV`, `HOST-BUG`, `WIDTH`, `SPEC-AMBIGUOUS`, `WINDOWS`, `EMULATED`, `FAILS`) must fail. A line that matches no failure in a way it names fails the run as stale. This is pytest's `xfail(strict=True)` and DejaGnu's XPASS.
  - **Lenient ones** (`HOST-FLAKY`, `FLAKY`) may pass or fail.
  - **Skips** (`HOST-ABSENT`, `XC1-NA`, `XC2-NA`, `UNTESTED`, `UNSUPPORTED`) are not run, and are listed with their reason.
  - **Quarantine** (`QUARANTINE until DATE`) runs and is reported, and never fails the run until the date, when the line is stale.
  - **The files stay where they are**; their readers become one.
* **C. Annotations in the tests only, as pytest's markers and GHC's `expect_broken` are.** A deviation of a host is about the host, not the test, and 497 `HOST-BUG` lines would clutter the tests.

`deviations.txt` already has these meanings: categories, stale lines, and
HOST-FLAKY's leniency (`tests/basis/run-matrix.sh:1603-1626`). B keeps
them, and gives them to every suite.

### D17. Flaky tests

**Decided: C** (2026-10-12), as recommended.

* **A. Nothing for Rune's own tests, as today.**
* **B. Retries by default, as Bazel's `flaky_test_attempts` and much of industry practice provide.**
* **C. Retries only where declared.** **Recommended.**
  - **No blanket retries.** A test is retried only where it is marked: a `FLAKY` expectation, or `retries=N` in its metadata.
  - **The verdict:** a failure followed by a pass is FLAKY. It does not fail the run, and every attempt is recorded.
  - **From history:** each test's flip rate, and the QUARANTINE category.
  - **To look into one:**
    - `--repeat N`;
    - `--until-fail`;
    - `--under-load`, which runs the test beside a load of its own, as Shaker does.
* **Why C:**
  - Rune's oracles are deterministic, so a blanket retry would hide what should never vary, such as a collector race (*What is different*, 6).
  - The flaky tests known so far are the machine's load: the fork and wait checks of `Posix.ProcEnv` and `Unix.exit`, `OS.FileSys.hash/spread`, SML/NJ's reals under parallel load, and Windows `.exe`s that WSL fails to start (`tests/basis/deviations.txt`, the HOST-FLAKY lines).
  - Those are answered by declaring them, by the load cap (D12) and by pools.
  - In CI, 9 of 168 runs failed on commits that passed unchanged on another run (E7). Two of the three causes were the environment, which D11 removes, and the third is unexplained.
* **What the literature adds** (*What the literature says*, *Flaky tests*):
  - **A retry runs in a fresh process.** Reruns in the same process confirmed a quarter of what fresh ones did.
  - **Load causes flakiness.** Nearly half of flaky tests are affected by the resources they get. So the load and the slots are recorded with each result (D13).
  - **A flaky test still finds faults.** Flaky tests revealed a third of Chromium's regression faults, and Google's "flaky until it fails three times" hid real breaks. So a FLAKY verdict is listed in the summary, never silent, and a QUARANTINE line carries a date after which it is stale.
  - **The practice to copy is Microsoft's:** one retry, a bug filed, and suppression that expires after a set time.

### D18. Requirements and the doctor

**Decided: B** (2026-10-12), as recommended.

* **A. As today:** `scripts/doctor.sh` (562 lines, eleven scopes) and the Makefile's stamps (`build/.doctor-<scope>`). At test time each script decides for itself what a missing tool means:
  - exit 2, as `run-portability.sh` does without qemu;
  - a skip with exit 0, as `tests/terminal/run.sh` does without tmux;
  - nothing at all, as `run-debug.sh` does with `readelf`.
* **B. Tests declare capabilities.** **Recommended.**
  - **What a capability is:** a value with a probe command, a version pattern and an install hint per package manager. Examples: `mlton@20241230`, `tmux`, `qemu-ppc64`, `windows-interop`, `python3:jupyter_client`, `cc-m32`, `gdb`.
  - **Prior art:** Erlang's Common Test `require`, lit's `REQUIRES:` and Bazel's `requires-*` tags.
  - **The doctor:** `rune-test doctor FILTER` probes what the selection needs, and only that.
  - **A missing capability** is an error in the `check` tier, and a skip with its reason in the tiers for development.
* **C. B, and `scripts/doctor.sh` retired.** This cannot be done. `make doctor` must run before `bin/rune` exists, so its C compiler and host scopes stay shell.

The inventory already knows what each test needs (B), so the doctor follows
from it. That is the brief's "find declared third-party packages from the
test set".

### D19. Modes

**Decided: the modes and exit codes listed** (2026-10-12), as recommended.

| Mode | What it does | Prior art |
|---|---|---|
| `list [--json]` | the inventory; runs no test body | nextest list, `pytest --collect-only` |
| `doctor` | D18 | |
| `run` | the run | |
| `--failed` | the last run's failures | HSpec `--rerun`, pytest `--lf`, ExUnit `--failed` |
| `--resume` | the tests an interrupted run had not finished, with the same inputs | |
| `--from PATH` | from a path on | pytest `--stepwise` |
| `--repeat N`, `--until-fail` | D17 | GoogleTest `--gtest_repeat` |
| `--accept` | D6 | |
| `explain PATH` | a test's steps, sidecars, expectations and requirements | |
| `stats` | the slowest, flakiest and largest tests from history | |

* **Exit codes:**
  - 0 when every test passed or was expected to fail;
  - 1 when one failed;
  - 2 for a usage error;
  - 125 when the tree was not built or a capability is missing, so that `git bisect run` skips the commit.
* **Command steps** keep Automake's and Meson's convention: 77 is a skip and 99 a hard error.
* **An interrupt** writes what is known.
* **Left out:** bisection of test-order interactions (testrepository's `--analyze-isolation`). Separate processes and workers make them unlikely.

### D20. How the runner is built

**Decided: A** (2026-10-12), as recommended.

* **A. By `$(RUNE)`, run on `bin/runevm`, as `rune-kernel` and `rune-dap` are built and run.** **Recommended.**
  - The register VM with its JIT is the default for every operation (the owner, 2026-10-09).
  - Canaries guard against a runner that a broken compiler built (*Testing the tester*).
* **B. By the compiler that MLton built (`bin/rune-mlton`)**, independent of the self-hosted compiler. One line of the Makefile, should A ever hide a failure.
* **C. As native code from `runeopt`.** The runner spends its time waiting, not computing.
* **D. In Python.** That would keep the scripts' language, against the brief.

The core (`lib/test/unit`) must build on every host. The runner need not.

### D21. `make check`

**Decided: B** (2026-10-12), as recommended.

* **A. Keep the 32 steps, and replace the scripts under them one by one.** Simple. But the steps stay serial, because they share `tests/out`, and the idle tails and the oversubscription stay too (E1).
* **B. Make builds, then the runner runs once.** **Recommended.**
  - `make check` is `make check-tools`, every tool the tests need, then `bin/rune-test run --tier check`.
  - One scheduler for all, and directories of their own instead of a shared `tests/out`.
  - The old targets stay as filters (`make test-basis` is `rune-test run 'basis & way:stack'`), so habits, scripts and documents keep working.
* **C. The runner drives the builds too**, with make's targets as nodes, so that the host builds overlap the tests. Later. E4's schedule reaches the CPU bound without it.

### D22. Tiers and selection

**Decided: A and B** (2026-10-12), as recommended.

* **A. Tiers by tag and by profile.** **Recommended, with B.**
  - **Prior art:** Alcotest's `Quick` and `Slow`, Bazel's sizes and nextest's profiles.
  - **`quick`**, under a minute, with every test in its first way only, as GHC's testsuite does at its normal speed:
    - `tests/lang` in the default way;
    - the libraries' cores;
    - `tests/doc`;
    - a sample of the Basis suite chosen by its history.
  - **`check`**: today's coverage, in the time that one schedule and shared compiles allow: on the calls E4 modelled, a little over half of today's.
  - **Profiles per kind of change**, which encode AGENTS.md's extra targets: `vm`, `layout`, `library`, `windows`, `portability`, `docs`.
  - **`nightly`**: the matrix, the hosts, stress, asan, deep laws and the benchmarks.
* **B. Selection by declared coverage.** Each group says which source paths it covers, by globs: `lib/json/**` selects the json, kernel and dap groups. `--affected [REV]` selects the groups that cover what changed since REV. A path that no group covers selects everything. **Recommended, with A.**
  - **Prior art:** ExUnit's `--stale`, Jest's `--findRelatedTests` and Bazel's reverse dependencies.
* **C. Selection from recorded file reads, as Ekstazi, the Go test cache and RTSLinux do.** Later. Almost every test reads `bin/rune` and `bin/runevm`, which change with every change to the compiler, so files are too coarse a unit here.
* **D. Predictive selection, as Facebook's is.** It needs years of results; Rune has none.

**What it means for agents.**
* Iterate with `--affected` or a profile.
* Before finishing, run `make check`, as today but in less time.
* A change to documentation alone runs what the map selects.
* CI runs `check` on pull requests, and a nightly workflow runs `nightly`.

**On the history** (E11):
* of the 470 commits since the repository began, 67% change the compiler, the runtime, the Basis or the build, and select everything;
* 20% change only prose, and 5% only tests.

Selection pays for about a third of the commits. The schedule is what serves the rest.

### D23. Migration

**Decided: B** (2026-10-12), as recommended.

* **A. Everything at once.**
* **B. Suite by suite.** **Recommended.**
  - **The commit:** each milestone retires named scripts in the same commit.
  - **Before deleting:** a shadow run on one commit runs the old and the new, and their verdicts must agree. Planted faults must each be reported: a wrong `.expected`, a loop, a segfault, an output flood, and a leaked process.
* **C. New tests only.** It proves the library on nothing that matters.

**What becomes SML:**
* all control over tests: the `xargs` loops, the `.result` files, the summaries, the skip lists and the timing tables;
* the comparisons;
* the protocol drivers wherever an SML library exists: `lib/jsonrpc`, `lib/dap`, `lib/jupyter` with `lib/zmtp`, and `rune --serve`'s JSON lines.

**What stays, as a step inside a test** (the brief's "foundational" scripts):
* tmux and `tests/terminal/term.py`, until the runtime has a pty (G8);
* Jupyter's own Python client, the third-party oracle of `tests/kernel`;
* the C reference programs;
* the qemu and WSL launchers;
* `scripts/install.sh`, which is what `tests/install` tests;
* the host compilers' command lines, as data in SML.

Generators and measurement tools are out of scope: `gen-*.sh`, `perf-*.sh`,
`gc-eval*`, `measure-benchmarks.sh`. *Appendix A* lists every script with
its fate.

### D24. Windows

**Decided: A** (2026-10-12), as recommended.

* **A. The runner stays on Linux and drives the Windows VMs through WSL's interop, as `make test-windows` does.** **Recommended.**
  - A `windows-interop:k` pool and a timeout multiplier answer the `UtilAcceptVsock` failures under load.
  - The new primitives get their `sys_win.c` halves anyway, as the system layer's rule requires. Suites on `lib/test/unit` run on `runevm.exe` as programs.
* **B. A native Windows runner**, with spawn and job objects in place of fork. Later.

## The milestones

**The rules every milestone keeps.**
* Every milestone is one commit or a few, each with `make check` green, as the repository's rules require.
* A milestone that retires a script retires it in the commit that replaces it. Before that commit, a shadow run on one tree shows the old and the new verdicts agreeing, and the planted faults reported (D23).
* Where a milestone touches a library, it also runs `make matrix-quick` and `make test-lib-hosts`. Where it touches the runtime, it also runs `make test-windows` and `make test-portability`.

**Sizes** are lines of SML with their tests, estimated: about 17,000 in all.
They retire about 11,000 lines of shell, Python and awk (*Appendix A*).

M1 and M2 are independent of each other and of the rest.
* **Part 1 of the brief, the library:** M1 to M3 (the core, the runtime's part, the runner).
* **Part 2, the scripts:** M3 to M14.
* **Part 3, the calibration:** M5 and M15.

### M1. `lib/test/unit`, and the libraries' tests on it (M, about 1,500)

* **What:**
  - The core of D1 to D6 (*The tree*): `TEST`, `EXPECT`, `GOLDEN`, `Test.property`, and the functor `Main` with plain and event output.
  - Its own tests, run on the five hosts.
  - runedoc pages, `docs/generated/test/unit`.
  - The pilot: the hand-written `check` functions of `tests/lib` (about twenty: digest, json, jsonrpc, dap, zmtp, jupyter, markdown, pretty, unicode, terminal, random, property) become suites on it.
  - `tests/lib/run-lib-tests.sh` still runs the programs, and reads their `PASS`/`FAIL` lines as it does today.
* **Why now:** it needs nothing else, and the libraries' tests are real users that will shake out the API before the runner is built on it.
* **Done when:**
  - the pilot suites report what they reported, check by check;
  - `make test-lib-hosts` passes on every host, with any failure a `HOST-BUG` line and a report;
  - `make docs` documents the library in full.
* **Done** (2026-10-12):
  - **The library**, `lib/test/unit`, written on `lib/test/property`, every file portable (`host yes`):
    - `Expect` (`check`, `that`, `eq`, `equal`, `raises`, `fail`, `run`), in the shapes of the Basis suite's `T`;
    - `Golden` (`check`, `difference`, the accept mode);
    - `Test` (`it`, `describe`, `tag`, `timeout`, `requires`, `resources`, `pending`, `ways`, `map`, `leaves`, `property`, `golden`);
    - `TestFilter` (the language of D4);
    - `Suite` and the functor `Main`, with `--list`, `--list-meta`, `--filter`, `--run`, `--after`, `--events`, `--accept` and `--quiet`.
  - **Its own tests**, `tests/lib/unit/core.sml`, under a harness of a dozen lines that does not use the library: the tree, the filters, the checks, golden files, the options and the events. They pass on Rune and on the six hosts.
  - **Two portability findings.** MLKit's `exnMessage (Fail s)` is `"Fail"`, without the message, so `Expect` matches `Fail` itself. SML/NJ wants the type of a record pattern with `...` in a local function written out.
  - **The pilot.** 17 programs of `tests/lib` are suites on the library: digest, markdown's CommonMark examples (652 tests, one per example), jupyter, dap, jsonrpc, json's round trips and JSONTestSuite (318 tests, one per file), random's properties, terminal's style, key, emulator, probe and edit, pretty, unicode's grapheme breaks (853 tests, one per line) and UTF-8, and zmtp. Every check of each was kept, and each was shown to fail when one of its checks was made to fail. `tests/lib/property` keeps its own form: its outputs are fingerprints that other scripts read.
  - **Documentation:** `docs/generated/test/unit`, and a section *Writing a test* in `docs/testing.md`. AGENTS.md says a library's tests are suites on the library.

### M2. The runtime's part (S–M, about 600)

* **What:** G1 to G5 (*What the runtime must add*), with `sys.h` and its three layers, `rune-prim.sml`, the rows of `docs/language.md`, the documented members and their tests.
* **Why now:** it is independent of M1, and M3 wants it. The Windows halves are the risk, so they come early.
* **Done when:** the suite's new checks pass on every configuration, `make test-windows` and `make test-portability` included.
* **Done** (2026-10-12):
  - **The system layer** (`runtime/sys/sys.h`): `sys_spawn_with` (a directory, a process group or a job, default signals, four limits), `sys_wait_usage` (`wait4`; `GetProcessTimes` and the peak working set on Windows), `sys_kill_group` (`kill (-pid)`; `TerminateJobObject` on Windows) and `sys_processors` (the affinity mask on Linux; `GetActiveProcessorCount` on Windows), in `sys_posix.c`, `sys_win.c` and `sys_none.c`. `sys_clock_ns` existed in all three.
  - **Five primitives**, added after every other so that none is renumbered: `rt_clock_ns`, `rt_processors`, `proc_spawn`, `proc_wait` and `proc_kill`, with their stubs for the hosts.
  - **The library:** `Runtime.clock` (G1) and `Runtime.processors` (G3), and a new structure `Subprocess` (`spawn`, `wait`, `poll`, `kill`, `limits`; G2, G4, G5), `Status: extension`, `host=no`. A process and a descriptor are given by number, as `RuneRuntime.spawn` gives them: the library is elaborated against the `Posix` that is not yet sealed, whose `pid` and `file_desc` a program never sees.
  - **Tests:** `tests/lang/basis.subprocess.sml`, which runs on POSIX and on Windows (sh and cmd.exe), and the Basis suite's `tests/basis/subprocess.sml` (14 checks: exit statuses, the environment, `PATH`, a pipe, any child, polling, a grandchild ended with its group, the file-size and processor-time limits and none, the costs) and three checks of `Runtime.clock` and `processors` in `tests/basis/runtime.sml`.
  - **Documentation:** the rows `basis.subprocess` and `basis.runtime` of `docs/language.md`, the primitives in `docs/bytecode.md`, and the generated pages.

### M3. The runner, with `make check`'s steps as its first jobs (L, about 2,300)

* **What:** the runner (*The run*, *The scheduler*, *Records and history*, *Output*):
  - the supervisor and the pure scheduler;
  - filters, records and history;
  - retention and the display;
  - the command line and the canaries;
  - properties of the scheduler.
* **Its first inventory:** each step of today's `make check` becomes one opaque job (`make --no-print-directory test-gc`, ...). Edges stand where steps share `tests/out` or `bin/`, and pools and CPUs are measured (E1, E2).
  - `make check` becomes `make check-tools` and `bin/rune-test run --tier check` (D21).
  - The job the scheduler places is today's make step, unchanged.
* **Retires:** the 32 steps of the `check` recipe (`Makefile:1395-1427`).
* **Why now:** every later milestone moves tests into it, and from the first run the runner records every step: the baseline the calibration needs.
* **Done when:**
  - the same verdicts as the old recipe, on a green tree and with each planted fault;
  - an idle baseline of the old recipe measured first, on the same machine, and the runner no slower than it;
  - every failure's output kept, and CI's artefact the summary of the whole run.

### M4. `tests/lang` and `tests/errors` in ways, compiled once (M, about 800)

* **What:** one kind of program test reading the sidecars (D6), and the ways of every `run-tests.sh` call in the Makefile (D7). These include the six hosts' compilers of `test-all`, the VMs of `test-gc`, `test-heap` and `test-register-jit`, and native code. Each distinct compile is done once (D8).
* **Retires:** the Makefile's calls of `run-tests.sh`, and the wrapper VMs it writes into `bin/`. `run-tests.sh` stays for the portability and Windows runners until M13.
* **Why now:** it is the largest saving measured (E3). The prototype did it in about 250 lines, with a third fewer compiles and every verdict kept (E9).
* **Done when:** the same verdicts, and E1 measured again.

### M5. The first calibration (S, about 300, and documents)

* **What:**
  - the `quick` tier and the profiles of D22;
  - a first `--affected` over the jobs and the ways that exist by then;
  - AGENTS.md's paragraph on what to run, rewritten for the profiles (*What changes for agents*).
* **Why now:** part 3 of the brief should not wait for part 2 to finish. Agents spend the most time in tests now.
* **Done when:** each profile's selection is listed in `docs/testing.md`, and E11 is repeated on the commits since this roadmap.

### M6. One engine for expectations (M, about 600)

* **What:** D16. `tests/opt-skip.txt`, `tests/windows-skip.txt`, `tests/portability-skip.txt`, `tests/external/mlton-skip.txt` and `tests/lib/deviations.txt` are read by one engine, in one format. `deviations.txt` and `law-skips.txt` follow in M7 and M8.
* **Done when:** stale lines are found as they are now, and each category's meaning has a test.

### M7. The Basis suite on the runner (M, about 900)

* **What:**
  - `T` (`tests/basis/harness.sml`) on the core's checks, its calls unchanged for runedoc;
  - the Basis suite's `rune` configurations of `make check` (`rune`, `rune:new`, `rune:jit`, `rune:opt`) as ways;
  - `deviations.txt` read by the engine of M6;
  - `tests/basis/run-examples.sh`.
* **Retires:** `run-examples.sh` (51 lines), and `run-matrix.sh`'s part in `make check`.
* **Done when:** the same checks pass and fail, the same deviation lines are used and stale, and the per-program times are in the history.

### M8. Laws on the runner (S–M, about 500)

* **What:** runedoc's law programs as suites. The runner's filter, resume and worker restart replace `Check.laws`' environment variables and `run-laws.sh`'s watchdog. `law-skips.txt` is read by the engine of M6.
* **Retires:** `tests/basis/run-laws.sh` (205 lines).
* **Done when:** the laws' results are those of `run-laws.sh`, and a law that hangs is stopped and the run goes on after it.

### M9. The differential checks as oracles (M, about 900)

* **What:** "counts equal" and "bytes equal" as comparisons across ways (`docs/testing.md`, *The three oracles*).
* **Retires:**

  | Script | Lines |
  |---|---|
  | `check-jit.sh` | 217 |
  | `check-register.sh` | 117 |
  | `check-levels.sh` | 71 |
  | `check-units.sh` | 147 |
  | `check-positions.sh` | 66 |
  | `check-cross.sh` | 191 |
  | `check-doc-cross.sh` | 49 |
  | `check-opt-cross.sh` | 70 |
  | `check-reproducible.sh` | 76 |
  | **total** | **1,004** |

  Also the bootstrap's comparisons in the Makefile.
* **Done when:** each oracle fails on a planted difference of one byte, and of one count.

### M10. The tools' suites (L, about 1,500)

* **What:** `tests/lib`, `tests/doc`, `tests/ir`, `tests/units`, `tests/flexrec`, `tests/deps`, `tests/dynamic`, `tests/buildfile`, `tests/install`, and the Python checks of the compiler and the runtime. The small command-line suites may become cram transcripts (D6, C).
* **Retires:** about 1,800 lines, the interop wrappers included:

  | Script | Lines |
  |---|---|
  | `run-lib-tests.sh` | 298 |
  | `run-doc-tests.sh` | 175 |
  | `run-ir-tests.sh` | 60 |
  | `units/run.sh` | 166 |
  | `flexrec/run.sh` | 93 |
  | `deps/run.sh` | 72 |
  | `dynamic/run.sh` | 166 |
  | `buildfile/run.sh` | 122 |
  | `install/run.sh` | 126 |
  | `compiler/run-tests.py` | 83 |
  | `tests/runtime/run-vm-tests.sh` | 182 |
  | `run-limits.py` | 65 |
  | `run-gc-log.py` | 118 |

### M11. The protocol suites in SML (L, about 2,000)

* **What:** the drivers of `rune --serve`, the REPL's protocol, DAP and the Jupyter kernel, written on `lib/jsonrpc`, `lib/dap` and `lib/jupyter`. Also the REPL's transcripts, the diagnostics, and the incremental scenarios with their random edits. The terminal tests keep `term.py` as a step (G8).
* **Retires:** about 2,600 lines, with `plant.py` and the kernel's `windows.py`:

  | Script | Lines |
  |---|---|
  | `serve/run.py` | 78 |
  | `repl/run.sh` | 82 |
  | `drive.py` | 67 |
  | `repl-protocol/run.py` | 245 |
  | `kernel/run.sh` | 67 |
  | `client.py` | 265 |
  | `dap/run.py` | 195 |
  | `diagnostics/run.sh` | 67 |
  | `terminal/run.sh` | 125 |
  | `incremental/run.sh` | 805 |
  | `mutate.py` | 488 |
* **Kept:** `notebook_client.py`, which is Jupyter's own client and so an oracle from outside, and `term.py`.

### M12. Requirements and the doctor (S–M, about 500)

* **What:** D18. Capabilities are declared on the tests, and `rune-test doctor` probes them. `scripts/doctor.sh` keeps its scopes for what must be known before building, and the test scopes become capabilities. The Makefile's stamps go where the runner checks for itself.
* **Done when:** a machine without tmux, qemu, Windows or a host gets a skip with its reason in development and an error in `check`, and the install hints are those `doctor.sh` gives today.

### M13. The matrix, and the other machines (XL, about 3,000)

* **What:** `run-matrix.sh`'s configurations, hosts, `xc1` and `xc2` as ways and jobs. Its probes, its halving of a program into sections and its heap images become steps. Also the 32-bit, PowerPC and aarch64 VMs, the Windows VMs, and the hosts' runs of the libraries and the laws.
* **Retires:** about 3,100 lines:

  | Script | Lines |
  |---|---|
  | `run-matrix.sh` | 1,698 |
  | `run-portability.sh` | 163 |
  | `run-windows.sh` | 263 |
  | `windows-dir.sh` | 21 |
  | `tests/lib/run-hosts.sh` | 159 |
  | `run-laws-hosts.py` | 557 |
  | `run-tests.sh` | 242 |
* **Why so late:** most of its worth is outside `make check`, and it is the most host knowledge in one file. Its generators (`gen-host-basis.sh`, the `xc2` rewriters) stay as steps.

### M14. The rest, and the tools for flaky tests (L, about 1,500)

* **What:**
  - native code (`tests/opt`), the census, the simulators, the layouts, gcbench, the budgets, the benchmarks' smoke test and catalogue checks, the documentation's consistency checks, the mutants and the external corpora;
  - stress and the sanitizer as ways;
  - the timing jobs in the exclusive pool;
  - `--repeat`, `--until-fail`, `--under-load`, `stats` and the quarantine.
* **Retires:** about 2,300 lines, with the benchmarks' ad hoc checks and MLton's incremental scenarios:

  | Script | Lines |
  |---|---|
  | `run-opt-tests.sh` | 248 |
  | `run-counts.sh` | 63 |
  | `run-debug.sh` | 132 |
  | `run-bootstrap.sh` | 20 |
  | `run-perf.sh` | 168 |
  | `check-census.sh` | 63 |
  | the heapsim tests | 270 |
  | `layouts/check.sh` | 48 |
  | `gcbench/check.sh` | 55 |
  | `run-benchmarks.sh` | 50 |
  | `check-catalog.sh` | 39 |
  | `check-docs.sh` | 126 |
  | `check-claims.sh` | 122 |
  | `check-notes.sh` | 88 |
  | `run-mutants.sh` | 147 |
  | `run-mlton.sh` | 73 |
  | `run-mlton-bench.sh` | 147 |
  | `contrast.py` | 192 |

### M15. The final calibration (S–M, about 300, and documents)

* **What:**
  - selection informed by history;
  - a nightly workflow in CI;
  - the summary and JUnit in CI;
  - AGENTS.md and `docs/testing.md` final;
  - the legacy jobs and wrappers deleted;
  - E1 measured again, for a before-and-after table in `docs/testing.md`.

### Later

* **Suites as `_dynamic` plugins, in a long-lived runner that forks** (D10, B), if compiles prove the cost.
* **The runner drives make's builds too** (D21, C).
* **A pty in the runtime (G8),** so that `tests/terminal` leaves tmux and Python.
* **A VM budget per call (G9):** an in-process deadline without a worker.
* **Selection from recorded file reads** (D22, C), if the tools ever stop changing with every commit.
* **A native Windows runner** (D24, B).
* **Expectations in the test files** for `tests/errors` (D6, B).

### Why this order

* **The library first, on real users** (M1). The libraries' tests are small, portable and numerous, and a bad API shows there before the runner sets it in stone.
* **The runner early, wrapped around what exists** (M3). From the first commit every step is timed and every failure kept, and nothing has moved yet. The schedule improves as steps become tests.
* **The largest saving next** (M4), then a calibration (M5) that agents feel at once.
* **The expectations before the suites that need them** (M6 before M7 and M8).
* **The matrix last** (M13). Most of it runs outside `make check`, and it is the most fragile to move.

## Prerequisites and flags

* **Nothing outside this roadmap is needed.** M2 adds the primitives it uses. `lib/json` and `lib/terminal` exist, and so do `lib/test/property` and the unit cache.
* **No flag is needed.** The runner is a program and a library. `make check` switches to it in M3 with one commit, which can be reverted.
* **What the agents' instructions change** is listed in *What changes for agents*.

## Relation to the other plans

* **The property library** ([quickcheck.md](quickcheck.md)): M8 replaces its runner's protocol with the runner's filters and restarts (D5). Its D13, the Basis suite's `PASS`/`FAIL` form and the replay token, holds. Its *Later* list left "a VM budget per case" to the VM's roadmaps (here G9).
* **The hunt** ([quickcheck-hunt.md](quickcheck-hunt.md)): its re-runs of a failing law, with a `FLAKY` verdict when the verdict changes, are D17's verdict.
* **Incremental compilation** ([incremental-compilation.md](incremental-compilation.md)): its unit cache is what makes a suite cheap to compile (D10), and its `tests/incremental` scenarios move in M11.
* **Performance and the benchmarks** ([performance.md](performance.md), [benchmarks.md](benchmarks.md)): the timing jobs go to the exclusive pool, and the budgets (`perf-check`) stay counts. The benchmark catalogue is SML already (`examples/benchmarks/shared/catalog.sml`), and its smoke test becomes jobs in M14.
* **The REPL and the terminal** ([repl.md](repl.md)): `lib/terminal` draws the status line, and `Emulator` tests it. The terminal tests keep tmux until G8.
* **The JIT and the register VM** ([jit.md](jit.md)): `check-jit.sh`'s modes become ways and its comparisons oracles (M9). The default VM is its VM.
* **The heap layout and the collector** ([heap-layout.md](heap-layout.md), [garbage-collector-v2.md](garbage-collector-v2.md)): their harnesses (`tests/layouts`, `tests/gcbench`, the census) keep their oracles, as jobs (M14).
* **The weak points** ([weak-points.md](weak-points.md)): its note that `make check` went from 3 to 15 minutes is what part 3 answers. Its note that only SIGINT can be caught is why the runner is an event loop.
* **`docs/testing.md`** gains a section on the runner (M3) and the before-and-after table (M15). Its rules become the runner's guarantees.

## What changes for agents

AGENTS.md's paragraph "Before finishing any change run `make check`" stays
true. Its list of extras per kind of change becomes profiles that the runner
knows (M5):

| Change | Today (AGENTS.md) | With the runner |
|---|---|---|
| while iterating | `make test RUNE=bin/rune-mlton` | `bin/rune-test run --affected` or a filter |
| before finishing | `make check` | `make check`: one run of the runner, a little over half the time where E4 measured |
| `runtime/register` | `test-register-asan`, `test-stress`, Windows, portability | `--profile vm` (adds the ways stress, asan, windows, ppc64, linux32) |
| heap, header, an emitter | `test-heap` | `--profile layout` |
| a library | `matrix-quick`, `test-lib-hosts` | `--profile library` |
| the documentation generator | `test-doc` | selected by `--affected` |
| a deviation line | `gen-annotations.sh`, `make docs` | unchanged (a generator) |

An agent that reads a log reads the failure blocks and the `RESULT:` line
(D14). A run that dies leaves its events, and `--resume` continues it.

## Risks

* **The runner trusts the compiler and the VM it tests.** A broken compiler can build a runner that passes everything. The canaries (*Testing the tester*) fail such a run; D20's option B builds the runner with MLton's compiler instead.
* **A check lost in the move.** A script can check something subtle that its replacement forgets. Shadow runs on the same tree, planted faults, and a list in each milestone of what each retired script checked (*Appendix A*).
* **Counts that change with paths.** The job directories have a fixed width and the shape of the root (*The run*). The prototype ran `tests/lang` and `tests/errors` that way with the verdicts unchanged (E9).
* **Legacy jobs racing in M3.** Today's steps share `tests/out` and write into `bin/`. Mutex pools serialise what shares, and every tool is built before the run starts.
* **The runner becoming a build system.** Make builds and the runner tests (D8, D21). A step never rebuilds a tool.
* **Overhead on the happy path.** The loop, the file comparisons, a runner running on the VM it tests. The prototype spent 8.5 s of CPU on 1,566 jobs whose own CPU was 396 s, 2% (E9).
* **The compile cost of suites.** The unit cache, and few, larger suites (D10); E5.
* **The matrix's hard-won host logic** (1,698 lines). It moves last (M13), and its generators stay as steps.
* **WSL's interop under load.** A pool of k and a timeout multiplier for the Windows way (D24).
* **Agents ignoring the tiers.** AGENTS.md says which profile a change needs, and `make check` stays the gate.
* **A selection that misses a failure.** A path no group covers selects everything. CI runs the whole `check`, and E11 measured the map on past commits.
* **History without bound.** One TSV rewritten per run, and run directories evicted by a budget (D15).
* **Evidence from a noisy machine.** The measurements took the machine's lock, but the performance roadmap's untimed jobs ran beside them, about 5 CPUs on average. Each run recorded the load, the document reports CPU time beside wall time, and its conclusions rest on ratios and counts. The absolute wall times of E1 should be measured again on an idle machine, as M3 does.

## Testing the tester

1. **Canaries in every run of `check`.** Tests that must fail, time out, crash, overflow their output and leave a process behind, each held to its verdict by a strict expectation. If a canary gets another verdict, the run is invalid, whatever else passed.
2. **Properties of the pure parts**, written with `lib/test/property`:
   * the scheduler on a simulated clock: never more than the resources, every edge kept, no job starved, the LPT bound, the same order from the same input;
   * the filter's parser and matcher;
   * the expectation engine's stale lines.
3. **The core under a harness of its own.** `lib/test/unit`'s own tests run under a dozen lines that do not use it, on every host. This is HSpec's `hspec-meta`: a frozen copy that tests the framework.
4. **The display through `Emulator`.** The status line and the failure blocks are drawn into `lib/terminal`'s emulator, and the screens are compared.
5. **Shadow runs and planted faults** for every retired script (D23).
6. **Determinism.** The same inventory and the same order on every run, on every VM and under every way.

## Appendix A: the scripts, and what becomes of them

Every script under `tests/`, `scripts/` and `tools/` at `34b2b4c5` (E10's census: 152 files, 14,321 lines of shell, 6,873 of Python and 727 of awk), with the milestone that retires it, or why it stays.

| Fate | Scripts | Lines |
|---|---|---|
| M7, The Basis suite | `tests/basis/run-examples.sh` (51) | 51 |
| M8, Laws | `tests/basis/run-laws.sh` (205) | 205 |
| M9, The differential checks | `scripts/check-cross.sh` (191), `scripts/check-doc-cross.sh` (49), `scripts/check-jit.sh` (217), `scripts/check-levels.sh` (71), `scripts/check-opt-cross.sh` (70), `scripts/check-positions.sh` (66), `scripts/check-register.sh` (117), `scripts/check-reproducible.sh` (76), `scripts/check-units.sh` (147) | 1,004 |
| M10, The tools' suites | `tests/buildfile/run.sh` (122), `tests/compiler/run-tests.py` (83), `tests/deps/run.sh` (72), `tests/doc/run-doc-tests.sh` (175), `tests/dynamic/run.sh` (166), `tests/flexrec/run.sh` (93), `tests/install/run.sh` (126), `tests/ir/run-ir-tests.sh` (60), `tests/lib/jupyter/interop.sh` (29), `tests/lib/run-lib-tests.sh` (298), `tests/lib/zmtp/interop.sh` (19), `tests/runtime/run-gc-log.py` (118), `tests/runtime/run-limits.py` (65), `tests/runtime/run-vm-tests.sh` (182), `tests/units/run.sh` (166) | 1,774 |
| M11, The protocol suites | `tests/dap/run.py` (195), `tests/diagnostics/run.sh` (67), `tests/incremental/mutate.py` (488), `tests/incremental/plant.py` (69), `tests/incremental/run.sh` (805), `tests/kernel/client.py` (265), `tests/kernel/run.sh` (67), `tests/kernel/windows.py` (63), `tests/repl-protocol/run.py` (245), `tests/repl/drive.py` (67), `tests/repl/run.sh` (82), `tests/serve/run.py` (78), `tests/terminal/run.sh` (125) | 2,616 |
| M12, The doctor (its test scopes; the build scopes stay) | `scripts/doctor.sh` (562) | 562 |
| M13, The matrix and the other machines | `tests/basis/run-laws-hosts.py` (557), `tests/basis/run-matrix.sh` (1698), `tests/lib/run-hosts.sh` (159), `tests/run-portability.sh` (163), `tests/run-tests.sh` (242), `tests/run-windows.sh` (263), `tests/windows-dir.sh` (21) | 3,103 |
| M14, The rest | `scripts/check-census.sh` (63), `scripts/check-docs.sh` (126), `scripts/run-benchmarks.sh` (50), `tests/basis/check-claims.sh` (122), `tests/basis/check-notes.sh` (88), `tests/basis/run-mutants.sh` (147), `tests/benchmarks/check-catalog.sh` (39), `tests/benchmarks/check-classic.sh` (27), `tests/benchmarks/check-measurement.sh` (26), `tests/benchmarks/check-pilots.sh` (71), `tests/benchmarks/check-queens.sh` (12), `tests/benchmarks/check-state.sh` (38), `tests/color/contrast.py` (192), `tests/external/run-mlton-bench.sh` (147), `tests/external/run-mlton.sh` (73), `tests/gcbench/check.sh` (55), `tests/incremental/mlton.sh` (86), `tests/layouts/check.sh` (48), `tests/opt/run-bootstrap.sh` (20), `tests/opt/run-counts.sh` (63), `tests/opt/run-debug.sh` (132), `tests/opt/run-opt-tests.sh` (248), `tests/perf/run-perf.sh` (168), `tools/heapsim/test.sh` (53), `tools/heapsim/test2.sh` (113), `tools/heapsim/validate.sh` (104) | 2,311 |
| **retired** | 73 scripts | **11,626** |
| stays, as a step inside a test (D23) | `scripts/runevm-native.sh`, `tests/basis/host/gen-host-basis.sh`, `tests/basis/xc2/flatten.sh`, `tests/basis/xc2/mlb-flatten.awk`, `tests/basis/xc2/mlkit/gen.sh`, `tests/basis/xc2/mlkit/rewrite.awk`, `tests/basis/xc2/mlton/gen.sh`, `tests/basis/xc2/mlton/prims.awk`, `tests/basis/xc2/mlton/rewrite.awk`, `tests/basis/xc2/polyml/gen.sh`, `tests/basis/xc2/polyml/order.awk`, `tests/basis/xc2/polyml/rewrite.awk`, `tests/basis/xc2/smlnj-dev/gen.sh`, `tests/basis/xc2/smlnj-legacy/gen.sh`, `tests/basis/xc2/smlnj-legacy/rewrite.awk`, `tests/basis/xc2/toplevel.awk`, `tests/basis/xc2/trim-lib.sh`, `tests/benchmarks/kb-oracle.py`, `tests/benchmarks/latency-oracle.py`, `tests/benchmarks/life-oracle.py`, `tests/benchmarks/qsort-oracle.py`, `tests/benchmarks/smith-oracle.py`, `tests/kernel/notebook_client.py`, `tests/lib/jupyter/interop/client.py`, `tests/lib/zmtp/interop/peer.py`, `tests/opt/rbcasm.awk`, `tests/opt/real-g.awk`, `tests/terminal/ptyraw.py`, `tests/terminal/term.py` | 2,294 |
| out of scope: generators, measurement and analysis tools, set-up, `install.sh` (the thing under test) | `scripts/benchmark-inventory.py`, `scripts/bisect-fuel.sh`, `scripts/build-files.sh`, `scripts/census.sh`, `scripts/cloud-cache.sh`, `scripts/envcheck.sh`, `scripts/fetch-hosts.sh`, `scripts/gc-eval-score.py`, `scripts/gc-eval.sh`, `scripts/gc-probe32.sh`, `scripts/gen-basis-sigs.sh`, `scripts/gen-build-files.sh`, `scripts/gen-entities.py`, `scripts/gen-unicode-tables.py`, `scripts/gen-version.sh`, `scripts/install.sh`, `scripts/measure-benchmarks.sh`, `scripts/ncpus.sh`, `scripts/opt.sh`, `scripts/perf-cycles.sh`, `scripts/perf-groups.awk`, `scripts/perf-repl.sh`, `scripts/perf-units.sh`, `scripts/smlnj-dev-root.sh`, `tests/basis/gen-annotations.sh`, `tests/basis/structures.sh`, `tests/benchmarks/test-inventory.py`, `tests/external/mlton-bench/gen-fxp-input.sh`, `tests/external/probe-host-basis.sh`, `tests/gcbench/measure.sh`, `tests/gcbench/report.py`, `tests/gcbench/roadmap.sh`, `tests/gcbench/tables.py`, `tests/layouts/measure.sh`, `tests/layouts/micro.sh`, `tests/layouts/tables.py`, `tests/lib/digest/gen-vectors.py`, `tools/heapsim/checkold.py`, `tools/heapsim/checktrace.py`, `tools/heapsim/pauses.py`, `tools/heapsim/pretenure.sh`, `tools/heapsim/report.py`, `tools/heapsim/report2.py`, `tools/heapsim/report3.py`, `tools/heapsim/sweep.sh`, `tools/heapsim/sweep2.sh`, `tools/heapsim/timeline.py`, `tools/heapsim/validate-proto.sh`, `tools/heapsim/validate2.sh`, `tools/mmu.py` | 8,001 |

## References

**Reading depth:**
* *full* means the paper's text was read where it held the claims cited;
* *part* means selected sections;
* *abstract* means the abstract alone;
* *secondary* means another source's account.

Entries with a DOI were rebuilt from Crossref's record.

### Papers and books

* Kent Beck. Simple Smalltalk Testing: With Patterns. *The Smalltalk Report*, October 1994. Reprinted in *Kent Beck's Guide to Better Smalltalk*, Cambridge University Press, 1997, pp. 277–288, doi:10.1017/CBO9780511574979.033. (full)
* Kent Beck, Erich Gamma. Test infected: programmers love writing tests. *Java Report* 3(7):37–50, 1998. Reprinted in *More Java Gems*, Cambridge University Press, 2000, pp. 357–376, doi:10.1017/CBO9780511550881.029. (full, the revised online text)
* Gerard Meszaros. *xUnit Test Patterns: Refactoring Test Code*. Addison-Wesley, 2007. (secondary: the author's pattern pages)
* Titus Winters, Tom Manshreck, Hyrum Wright. *Software Engineering at Google*. O'Reilly, 2020, chapters 11, 12, 14 and 23. (full)
* Sai Zhang, Darioush Jalali, Jochen Wuttke, Kıvanç Muşlu, Wing Lam, Michael D. Ernst, David Notkin. Empirically revisiting the test independence assumption. ISSTA 2014, pp. 385–396, doi:10.1145/2610384.2610404. (part)
* Jonathan Bell, Gail Kaiser. Unit test virtualization with VMVM. ICSE 2014, pp. 550–561, doi:10.1145/2568225.2568248. (abstract)
* Jonathan Bell, Gail Kaiser, Eric Melski, Mohan Dattatreya. Efficient dependency detection for safe Java test acceleration. ESEC/FSE 2015, pp. 770–781, doi:10.1145/2786805.2786823. (part)
* Alessio Gambi, Jonathan Bell, Andreas Zeller. Practical test dependency detection. ICST 2018, pp. 1–11, doi:10.1109/ICST.2018.00011. (abstract)
* Qingzhou Luo, Farah Hariri, Lamyaa Eloussi, Darko Marinov. An empirical analysis of flaky tests. FSE 2014, pp. 643–653, doi:10.1145/2635868.2635920. (full)
* Atif Memon, Zebao Gao, Bao Nguyen, Sanjeev Dhanda, Eric Nickell, Rob Siemborski, John Micco. Taming Google-scale continuous testing. ICSE-SEIP 2017, pp. 233–242, doi:10.1109/ICSE-SEIP.2017.16. (part)
* John Micco. Flaky tests at Google and how we mitigate them. Google Testing Blog, 27 May 2016, https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html. (full)
* Jonathan Bell, Owolabi Legunsen, Michael Hilton, Lamyaa Eloussi, Tifany Yung, Darko Marinov. DeFlaker: automatically detecting flaky tests. ICSE 2018, pp. 433–444, doi:10.1145/3180155.3180164. (part)
* Wing Lam, Reed Oei, August Shi, Darko Marinov, Tao Xie. iDFlakies: a framework for detecting and partially classifying flaky tests. ICST 2019, pp. 312–322, doi:10.1109/ICST.2019.00038. (part)
* Wing Lam, Kıvanç Muşlu, Hitesh Sajnani, Suresh Thummalapenta. A study on the lifecycle of flaky tests. ICSE 2020, pp. 1471–1482, doi:10.1145/3377811.3381749. (part)
* Wing Lam, Stefan Winter, Anjiang Wei, Tao Xie, Darko Marinov, Jonathan Bell. A large-scale longitudinal study of flaky tests. *PACMPL* 4(OOPSLA):1–29, 2020, doi:10.1145/3428270. (abstract)
* Denini Silva, Leopoldo Teixeira, Marcelo d'Amorim. Shake it! Detecting flaky tests caused by concurrency with Shaker. ICSME 2020, pp. 301–311, doi:10.1109/ICSME46990.2020.00037. (abstract)
* Emily Kowalczyk, Karan Nair, Zebao Gao, Leo Silberstein, Teng Long, Atif Memon. Modeling and ranking flaky tests at Apple. ICSE-SEIP 2020, pp. 110–119, doi:10.1145/3377813.3381370. (abstract)
* Abdulrahman Alshammari, Christopher Morris, Michael Hilton, Jonathan Bell. FlakeFlagger: predicting flakiness without rerunning tests. ICSE 2021, pp. 1572–1584, doi:10.1109/ICSE43902.2021.00140. (abstract)
* Owain Parry, Gregory M. Kapfhammer, Michael Hilton, Phil McMinn. A survey of flaky tests. *ACM TOSEM* 31(1):1–74, 2021, doi:10.1145/3476105. (part)
* Martin Gruber, Stephan Lukasczyk, Florian Kroiß, Gordon Fraser. An empirical study of flaky tests in Python. ICST 2021, pp. 148–158, doi:10.1109/ICST49551.2021.00026. (part)
* Denini Silva, Martin Gruber, Satyajit Gokhale, Ellen Arteca, Alexi Turcotte, Marcelo d'Amorim, Wing Lam, Stefan Winter, Jonathan Bell. The effects of computational resources on flaky tests. *IEEE TSE* 50(12):3104–3121, 2024, doi:10.1109/TSE.2024.3462251. (part)
* Fabian Leinen, Daniel Elsner, Alexander Pretschner, Andreas Stahlbauer, Michael Sailer, Elmar Jürgens. Cost of flaky tests in continuous integration: an industrial case study. ICST 2024, pp. 329–340, doi:10.1109/ICST60714.2024.00037. (abstract)
* Abdulrahman Alshammari, Paul Ammann, Michael Hilton, Jonathan Bell. 230,439 test failures later: an empirical evaluation of flaky failure classifiers. ICST 2024, pp. 257–268, doi:10.1109/ICST60714.2024.00031. (abstract)
* Owain Parry, Gregory Kapfhammer, Michael Hilton, Phil McMinn. Systemic flakiness: an empirical analysis of co-occurring flaky test failures. EASE 2025, pp. 476–487, doi:10.1145/3756681.3756945. (abstract)
* Guillaume Haben, Sarra Habchi, Mike Papadakis, Maxime Cordy, Yves Le Traon. The importance of discerning flaky from fault-triggering test failures: a case study on the Chromium CI. arXiv:2302.10594, 2023. (abstract)
* Gregg Rothermel, Mary Jean Harrold. A safe, efficient regression test selection technique. *ACM TOSEM* 6(2):173–210, 1997, doi:10.1145/248233.248262. (abstract)
* G. Rothermel, R. H. Untch, Chengyun Chu, M. J. Harrold. Prioritizing test cases for regression testing. *IEEE TSE* 27(10):929–948, 2001, doi:10.1109/32.962562. (abstract)
* S. Yoo, M. Harman. Regression testing minimization, selection and prioritization: a survey. *STVR* 22(2):67–120, 2012, doi:10.1002/stv.430. (abstract)
* Milos Gligoric, Stas Negara, Owolabi Legunsen, Darko Marinov. An empirical evaluation and comparison of manual and automated test selection. ASE 2014, pp. 361–372, doi:10.1145/2642937.2643019. (part)
* Sebastian Elbaum, Gregg Rothermel, John Penix. Techniques for improving regression testing in continuous integration development environments. FSE 2014, pp. 235–245, doi:10.1145/2635868.2635910. (part)
* Milos Gligoric, Lamyaa Eloussi, Darko Marinov. Practical regression test selection with dynamic file dependencies. ISSTA 2015, pp. 211–222, doi:10.1145/2771783.2771784. (part)
* Owolabi Legunsen, Farah Hariri, August Shi, Yafeng Lu, Lingming Zhang, Darko Marinov. An extensive study of static regression test selection in modern software evolution. FSE 2016, pp. 583–594, doi:10.1145/2950290.2950361. (part)
* Owolabi Legunsen, August Shi, Darko Marinov. STARTS: STAtic regression test selection. ASE 2017, pp. 949–954, doi:10.1109/ASE.2017.8115710. (abstract)
* Ahmet Celik, Marko Vasic, Aleksandar Milicevic, Milos Gligoric. Regression test selection across JVM boundaries. ESEC/FSE 2017, pp. 809–820, doi:10.1145/3106237.3106297. (part)
* Mateusz Machalica, Alex Samylkin, Meredith Porth, Satish Chandra. Predictive test selection. ICSE-SEIP 2019, pp. 91–100, doi:10.1109/ICSE-SEIP.2019.00018. (part)
* R. L. Graham. Bounds for certain multiprocessing anomalies. *Bell System Technical Journal* 45(9):1563–1581, 1966, doi:10.1002/j.1538-7305.1966.tb01709.x. (secondary)
* R. L. Graham. Bounds on multiprocessing timing anomalies. *SIAM Journal on Applied Mathematics* 17(2):416–429, 1969, doi:10.1137/0117039. (full)
* M. R. Garey, R. L. Graham. Bounds for multiprocessor scheduling with resource constraints. *SIAM Journal on Computing* 4(2):187–200, 1975, doi:10.1137/0204015. (part)
* Thomas L. Adam, K. M. Chandy, J. R. Dickson. A comparison of list schedules for parallel processing systems. *Communications of the ACM* 17(12):685–690, 1974, doi:10.1145/361604.361619. (abstract, and secondary)
* Yu-Kwong Kwok, Ishfaq Ahmad. Static scheduling algorithms for allocating directed task graphs to multiprocessors. *ACM Computing Surveys* 31(4):406–471, 1999, doi:10.1145/344588.344618. (part)
* Andrey Mokhov, Neil Mitchell, Simon Peyton Jones. Build systems à la carte. *PACMPL* 2(ICFP):1–29, 2018, doi:10.1145/3236774. (abstract)
* Andrey Mokhov, Neil Mitchell, Simon Peyton Jones. Build systems à la carte: theory and practice. *Journal of Functional Programming* 30, e11, 2020, doi:10.1017/S0956796820000088. (part)
* Hamed Esfahani, Jonas Fietz, Qi Ke, Alexei Kolomiets, Erica Lan, Erik Mavrinac, Wolfram Schulte, Newton Sanches, Srikanth Kandula. CloudBuild: Microsoft's distributed and caching build service. ICSE 2016 Companion (SEIP), pp. 11–20, doi:10.1145/2889160.2889222. (part)
* William M. McKeeman. Differential testing for software. *Digital Technical Journal* 10(1):100–107, 1998. (part)
* Xuejun Yang, Yang Chen, Eric Eide, John Regehr. Finding and understanding bugs in C compilers. PLDI 2011, pp. 283–294, doi:10.1145/1993498.1993532. (part)
* Vu Le, Mehrdad Afshari, Zhendong Su. Compiler validation via equivalence modulo inputs. PLDI 2014, pp. 216–226, doi:10.1145/2594291.2594334. (part)
* Junjie Chen, Jibesh Patra, Michael Pradel, Yingfei Xiong, Hongyu Zhang, Dan Hao, Lu Zhang. A survey of compiler testing. *ACM Computing Surveys* 53(1):1–36, 2020, doi:10.1145/3363562. (part)
* Moritz Beller, Georgios Gousios, Annibale Panichella, Andy Zaidman. When, how, and why developers (do not) test in their IDEs. ESEC/FSE 2015, pp. 179–190, doi:10.1145/2786805.2786843. (abstract)
* Moritz Beller, Georgios Gousios, Annibale Panichella, Sebastian Proksch, Sven Amann, Andy Zaidman. Developer testing in the IDE: patterns, beliefs, and behavior. *IEEE TSE* 45(3):261–284, 2019, doi:10.1109/TSE.2017.2776152. (abstract)
* Michael Hilton, Timothy Tunnell, Kai Huang, Darko Marinov, Danny Dig. Usage, costs, and benefits of continuous integration in open-source projects. ASE 2016, pp. 426–437, doi:10.1145/2970276.2970358. (part)
* Adriaan Labuschagne, Laura Inozemtseva, Reid Holmes. Measuring the cost of regression testing in practice: a study of Java projects using continuous integration. ESEC/FSE 2017, pp. 821–830, doi:10.1145/3106237.3106288. (part)
* John Yang, Carlos Jimenez, Alexander Wettig, Kilian Lieret, Shunyu Yao, Karthik Narasimhan, Ofir Press. SWE-agent: agent-computer interfaces enable automated software engineering. NeurIPS 2024, pp. 50528–50652, doi:10.52202/079017-1601. (part)
* Tobias Lindenbauer, Igor Slinko, Ludwig Felder, Egor Bogomolov, Yaroslav Zharov. The complexity trap: simple observation masking is as efficient as LLM summarization for agent context management. arXiv:2508.21433, 2025. (abstract)
* Yuhang Wang et al. SWE-Pruner: self-adaptive context pruning for coding agents. arXiv:2601.16746, 2026. (abstract)
* Ádám Kovács. Squeez: task-conditioned tool-output pruning for coding agents. arXiv:2604.04979, 2026. (abstract)
* Marcus Emmanuel Barnes, Taher A. Ghaleb, Safwat Hassan. LogSieve: task-aware CI log reduction for sustainable LLM-based analysis. MSR 2026, pp. 550–561, doi:10.1145/3793302.3793380. (abstract)

### Frameworks and runners

Read as of 2026-10-11, from documentation and, where behaviour mattered, source.

* SMLUnit: https://github.com/smlsharp/smlsharp/tree/master/src/smlunit
* mltonlib unit-test: https://github.com/MLton/mltonlib/tree/master/com/ssh/unit-test/unstable
* QCheck/SML 1.2: https://github.com/league/qcheck
* HOL4 testutils, selftest levels and Holmake's scheduler: https://github.com/HOL-Theorem-Prover/HOL (`src/parse/testutils.sml`, `Manual/Developers/developers.md`, `tools/Holmake/poly/multibuild.sml`, `tools/build/checkRegressions.sml`)
* Poly/ML `Tests/`: https://github.com/polyml/polyml/blob/master/Tests/RunTests.sml
* MLton `bin/regression`: https://github.com/MLton/mlton/blob/master/bin/regression
* MLKit kittester: https://github.com/melsman/mlkit/tree/master/src/Tools/Tester
* SML/NJ regression tests: https://github.com/smlnj/regression-tests
* HSpec 2.11.18: https://hspec.github.io, https://hackage.haskell.org/package/hspec-core
* Tasty 1.5.4, tasty-golden, tasty-rerun, tasty-expected-failure: https://github.com/UnkindPartition/tasty
* HUnit: https://hackage.haskell.org/package/HUnit
* OUnit2 2.2.7: https://github.com/gildor478/ounit
* Alcotest 1.9.1: https://github.com/mirage/alcotest
* ppx_inline_test, ppx_expect: https://github.com/janestreet/ppx_expect
* Dune cram tests and promotion: https://dune.readthedocs.io/en/stable/reference/dune/cram.html
* ocamltest: https://github.com/ocaml/ocaml/blob/trunk/ocamltest/OCAMLTEST.adoc
* LLVM lit and FileCheck: https://llvm.org/docs/CommandGuide/lit.html
* DejaGnu 1.6.3 and GCC's testsuite: https://gcc.gnu.org/onlinedocs/gccint/Directives.html
* Rust compiletest: https://rustc-dev-guide.rust-lang.org/tests/compiletest.html
* GHC testsuite: https://gitlab.haskell.org/ghc/ghc/-/wikis/building/running-tests
* pytest 9.1, pytest-xdist, pytest-timeout, pytest-rerunfailures: https://docs.pytest.org/en/stable/
* Go testing and test2json: https://pkg.go.dev/cmd/go, https://pkg.go.dev/cmd/test2json
* cargo-nextest 0.9.148: https://nexte.st
* Bazel 9.3: https://bazel.build/reference/test-encyclopedia
* CTest (CMake 4.4): https://cmake.org/cmake/help/latest/manual/ctest.1.html
* Meson 1.12: https://mesonbuild.com/Unit-tests.html
* Automake 1.19 parallel harness, Autotest (Autoconf 2.73): https://www.gnu.org/software/automake/manual/, https://www.gnu.org/software/autoconf/manual/
* JUnit 6: https://docs.junit.org/current/user-guide/
* ExUnit and `mix test` (Elixir 1.20): https://hexdocs.pm/mix/Mix.Tasks.Test.html
* GoogleTest: https://google.github.io/googletest/advanced.html
* Criterion: https://criterion.readthedocs.io; Check: https://libcheck.github.io/check/
* ninja 1.12-1.13: https://ninja-build.org/manual.html, `src/build.cc`
* stestr 4.2 and subunit: https://stestr.readthedocs.io, https://github.com/testing-cabal/subunit
* TAP 14: https://testanything.org/tap-version-14-specification.html
* GitHub Actions workflow commands and job summaries: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands
* Vitest 4.1 agent reporter: https://vitest.dev/blog/vitest-4-1.html; Jest 30.3; Bun; V8's `tools/testrunner/base_runner.py`
* Anthropic. Building a C compiler with a team of parallel Claudes. 5 February 2026, https://www.anthropic.com/engineering/building-c-compiler

