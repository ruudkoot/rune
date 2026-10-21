# Testing

How Rune's tests decide, without a human, that a run was right: the three
oracles the suites use, what a program's input is (more than the words on
its command line), and the rules a harness follows so that two runs it
compares differ only where the code differs. The evidence here was gathered
while the heap-layout roadmap was written, when an instrumented VM had to
report the same counts as the stock one on more than sixty programs and every mismatch
had to be explained.

Neighbouring pages: [building.md](building.md) lists the suites and the
`make` targets that run them; [runtime.md](runtime.md), *The same run
twice*, states what `--count` promises; [performance.md](performance.md)
is the budgets and the timing method; the roadmap
[plans/heap-layout.md](plans/heap-layout.md), *Testing a layout change*,
is what a change to the layout of values or objects has to pass;
*Measuring a collector* below is how a new collector is scored against
today's.

## Writing a test

A test written in Standard ML is a suite on `lib/test/unit`
([lib/test/unit](lib/test/unit/README.md); the roadmap
[plans/unit-testing.md](plans/unit-testing.md)): a tree of named tests,
`Test.describe "json" [Test.it "decode" (fn () => ...), ...]`, whose checks
(`Expect.that`, `Expect.eq`, `Expect.raises`) are soft, and a program
`Main (struct val name = "json" val tests = ... end)`. The program prints
`PASS path` or `FAIL path` with the failed checks for each test and a
`SUMMARY` line, and fails when a test failed. `--list` lists the tests
without running them, `--filter` selects (`lib/* & !tag:slow`), `--after`
goes on after a test, and `--events FILE` writes a JSON line as each test
starts and ends. The library builds on every host compiler, so the same
suite runs in `make test-lib` and `make test-lib-hosts`.

`make test-lib-hosts` runs the tier `test-lib-hosts`: twenty-four programs on
each of six native hosts (`lib-hosts/HOST/PROGRAM`), a shared C known-answer
reference, and a stale-deviation check per host. Filter a single host with
`bin/rune-test run 'lib-hosts/mlton/*'`, or a program with
`bin/rune-test run 'lib-hosts/*/random.kat'`. The native compilers come
from `RUNE_HOSTS` and the `MLTON`, `SMLNJ`, `SMLNJ32`, `SMLNJ_DEV`, `POLY`
and `MLKIT` overrides, with `MLKIT_LIB` for its Basis. The doctor probes
these executables separately from Rune's host builds. A program has 600
seconds per build or run (`LIB_HOST_TIMEOUT`), 2 GiB per child and 64 MiB per output file; the
scheduler budgets 2 GiB per job. Build directories are private, while
programs run in the repository root to read their fixtures. The same
`tests/lib/deviations.txt` explains host failures and rejects stale lines.
MLKit writes its cache beside the sources, so its builds share the
`matrix` pool with the Basis matrix; other native hosts can run beside it.
A child that leaves a process group behind is killed and fails, even if
it printed `PASS` before it exited.
Poly/ML uses a 2 GiB heap limit and 4 GiB of address space, since its
virtual-memory reservation prevents startup under the smaller bound.

## Running the tests

`make check` is `make check-tools`, which builds every tool a test needs,
and then `bin/rune-test run --tier check`. `bin/rune-test` is the runner
(`lib/test/runner`, [lib/test/runner](lib/test/runner/README.md)),
compiled by `bin/rune` from its inventory, `tests/runner/*.sml`, and run on
`bin/runevm`. Its tests are trees of commands: each runs as a process in a
group of its own, in a directory of its own under the run's directory
`tests/out/r/STAMP` or in the one it names, with its output and errors in
files, its signals at their defaults, a timeout (TERM, then KILL) and a cap
on its output. A test that ends and leaves processes behind fails with
`LEAK`. The scheduler starts the jobs whose critical path is longest first,
and the ones that failed last time before those; it fits them to the CPUs
and memory of the machine (`-j`, `--mem`; by default its processors less
its load, but at least half of them, and its available memory), keeps
apart the jobs that name one pool, and starts a job only after those it
waits for.

* `bin/rune-test list [FILTER]` lists the tests (`make/*`,
  `tag:check & !runner/*`), and `explain FILTER` shows each one's command,
  directory, CPUs, pools and edges;
* `bin/rune-test run [FILTER] [--tier T]` runs them; `--failed` runs those
  that failed last time and `--keep` keeps the directory of every test;
* `bin/rune-test stats` lists the slowest and the flakiest tests.

The output depends on who reads it. On a terminal, one status line and a
block for each failure as it happens; in a log or to an agent (recognised by
`AI_AGENT`, `CLAUDECODE` and the like), nothing for a test that passes, a
line every 30 seconds, and the same blocks. A block gives the verdict
(`FAIL`, `TIMEOUT`, `CRASH`, `LEAK`, `ERROR`), the reason with the lines of
the output that say what failed, the directory the test's output is kept in
(`tests/out/r/STAMP/failed/PATH`), the command, and the command that runs it
again. The last line begins `RESULT:`. Every run writes its events as JSON
lines (`events.jsonl`), a summary in Markdown (`summary.md`, and GitHub's
page of the job) and every verdict as JUnit's XML (`junit.xml`) in its
directory. The directories of tests that pass are
removed as they end, and the last five runs are kept. The wall time of each
test goes into `build/test-history.tsv`, from which the next run orders its
jobs.

### Tiers, profiles and what changed

A tier or a profile is a tag (`--tier T`, `--profile P`):

| Tag | What it selects |
|---|---|
| `quick` | `tests/lang` and `tests/errors` compiled by `bin/rune-stack` and run on `bin/runevm-stack`, the libraries' suites, the documentation generator's, the canaries, and every test that failed last time or whose verdict has changed between runs (the history; `--informed` adds those to any selection): under a minute (`make quick`) |
| `check` | all of `make check` |
| `test`, `test-heap`, `test-gc`, `test-all`, `test-native`, `test-register`, `test-register-jit` | the ways of `tests/lang` of that make target |
| `vm` | `make test-register-asan`, `test-stress`, `test-windows` and `test-portability`, for a change to `runtime/register` or the VMs |
| `layout` | `tests/lang` in `test-heap`'s ways, `make test-heap-steps` and `check-layouts`, for the heap, the headers and the emitters |
| `library` | `make matrix-quick` and `test-lib-hosts`, for a library |
| `windows`, `portability` | `make test-windows`, `test-portability` |
| `docs` | `make check-docs` and `test-doc` |
| `nightly` | what `make check` does not run: the profiles' extras, the VMs of other machines, every configuration of the matrix, native code under stress and the sanitizers; once a day in CI (`.github/workflows/nightly.yml`) |

The profiles `vm` and `library` hold what `make check` does not run; the
others are parts of it, to run alone while iterating.

`--affected` keeps the tests that cover what changed since `HEAD`
(`--since REV`, `--changed FILE`): each group of tests names the paths it
covers (`covers:GLOB`, in `tests/runner/*.sml`), and a changed path that no
group covers (the compiler, the runtime, the Basis Library, the Makefile,
the scripts) keeps every test. Of the 156 commits before 2026-10-12, 97 select
every test, 48 (documentation) `make check-docs` alone and 11 a few hundred
tests.

The programs of `tests/lang` and `tests/errors` are the runner's own tests
(`compile/COMPILER/NAME`, `lang/WAY/NAME`, `errors/COMPILER/NAME`;
`tests/runner/lang.sml`), and so are the Basis Library suite's in Rune's four
configurations and the examples of its documentation
(`basis-compile/COMPILER/TEST`, `basis/CONFIG/TEST`, `basis/CONFIG/@stale`,
`basis-examples/NAME`; `tests/runner/basis.sml`) and the laws of its
documentation (`laws-compile/NAME`, `laws/NAME@STRUCTURE`, each under a
watchdog that skips a case that hangs or runs out of memory and goes on;
`tests/runner/laws.sml`), and the differential checks, each program a job
that compares what it compiles and runs across levels, engines, builds and
hosts (`levels/*`, `register/*`, `jit/*`, `units/*`, `units-stack/*`,
`positions/*`, `cross/*`, `reproducible/*`, `bootstrap/*`;
`tests/runner/oracles.sml`), and the tools' suites (`ir/*`, `doc/*`, `lib/*`,
`flexrec/*`, `compiler/*`, `limits/*`, `gc-log/*`, `colour/*`, and the scenarios of
`tests/deps`, `tests/dynamic`, `tests/buildfile` and `tests/units` as
`scenario/*`; `tests/runner/tools.sml`), and the protocol suites (`repl/*`,
`diagnostics/*`, `serve/*` in SML; `repl-protocol/*`, `dap/*`, `kernel/*`,
`incremental/*` running their drivers a case at a time;
`tests/runner/protocols.sml`); the rest of `make check` is a step each, an
opaque `make` of its target (`tests/runner/main.sml`): the steps that run
the programs of `tests/lang` from the root of the tree share the pool
`lang` and run one at a time, and the others run beside them. Five
canaries, tests that fail on purpose (an exit with 1, a run past its time,
a crash, a flood of output and a leaked process), pass only when the
runner sees each fault for what it is; they run in every `make check`,
since the runner is built by the compiler it tests.

The remaining script migrations are tracked by
[the part-two roadmap](plans/unit-testing-part2.md) and
`tests/runner/migration.tsv`. `runner/migration-inventory` rejects unassigned
shell/Python/AWK files and invalid retirements; `runner/migration-faults`
plants omissions, duplicates and missing replacements. Both run in `check`
and `quick`. `bin/rune-test migration-baseline DIR` records the source state,
tool identities, callers and tier/profile selections before a migration.

Native generator checks are individual `native/opt/*` and `native/code/*`
cases (`tests/runner/nativechecks.sml`), with producer edges for the programs
they inspect. `bin/runevm-native` is a thin entrypoint to the SML translation
and cache policy in `tests/runner/nativevm.sml`. DWARF, binutils, gdb and lldb
requirements are recorded separately. Stack, register, JIT and native stress
and sanitizer runs use the language suite's way model; select them with
`--tier test-stress`, `test-register-asan`, `test-native-stress` or
`test-native-asan`. The Basis stress selections still call the matrix driver
until its P2.6 replacement.

Census, simulator, layout, gcbench and JIT-dump checks are `heap/*` cases
(`tests/runner/heap.sml`). Trace producers publish a successful recipe before
consumers can run; failed producers cancel their consumers. Consistency checks
use unsigned binary readers in SML, including malformed/truncated trace and
JIT records, numeric boundary cases and wrong checksums. Run individual groups
with `--tier test-census`, `check-heapsim`, `check-gcsim`, `check-layouts` or
`check-gcbench`. The standalone commands are
`bin/rune-heap-check heap-trace-check DIR` and
`bin/rune-heap-check heap-validate [--out DIR] WORKLOAD...`; both fail with a
nonzero status. Existing census archives retain their five-setting TSV reports.
Absent/stale standalone archives still use the production census adapter until
P2.14; the routine checks already use SML producers. The JIT analysis tool also
remains a production Python adapter until P2.14, with an explicit requirement.

### Before and after

`make check` before the runner was 32 steps run one after another
(2026-10-11, at `34b2b4c5`); on the runner it is `make check-tools` and one
run of 14,118 tests (2026-10-12). Both ran with 16 processors on this
machine while other work kept about five of them busy, so the CPU and the
processors each run kept busy compare better than the wall times
([plans/unit-testing.md](plans/unit-testing.md), E1 and M15).

| | Before: 32 steps | After: the runner |
|---|---|---|
| Wall time of the tests | 56.4 min | 20.1 min |
| CPU | 12,355 s | 11,879 s |
| Processors it kept busy, on average | 3.65 of 16 | 9.9 of 16 |
| Processors the machine kept busy, on average | 9.1 | 14.9 |

The CPU is about the same; the time went to the 18 steps that ran alone
and to the idle tails of the others. The longest tests now are a program
of `tests/errors` compiled by SML/NJ's build (348 s) and the laws of
`MONO_ARRAY2` on `LargeIntArray2` (292 s). `make check-tools` took another
8.2 minutes, a full rebuild, since a new commit's version is compiled into
the tools; the run before was on a build already made.

## Requirements

A test names the capabilities it needs of the machine (`Test.requires`):
`tmux`, `python3`, `cc`, `qemu`, `windows`, and each host
(`mlton`, `smlnj-legacy`, `smlnj32`, `smlnj-dev`, `polyml`, `mlkit`), each
a probe and an install hint in `tests/runner/main.sml`, the hints
`scripts/doctor.sh` gives. `bin/rune-test doctor [FILTER]` probes what the
selected tests need and says how to get what is missing. A run skips a test
whose capability is missing, with its hint; the tier `check` (and
`--strict`) fails it instead, since `make check` must be complete.
`RUNE_TEST_WITHOUT=tmux,qemu` takes those as missing, to see what a machine
without them gets. `scripts/doctor.sh` keeps its scopes for what must be
there before anything is built.

## Flaky tests

A test that passes and fails with nothing changed is flaky (D17). The
runner gives three ways to find one and two to live with it:

* `bin/rune-test run FILTER --repeat N` runs the selection N times, and
  `--until-fail` until a run fails (at most N times, 100 by default);
  `--under-load` keeps every processor busy beside the runs, which is what
  makes a test that races fail;
* `bin/rune-test stats` lists the tests whose verdict changed most often
  between runs (the history's flips);
* a test known to be flaky is tagged `flaky` in the inventory: when it
  fails it runs once more, and a pass then is `FLAKY`, reported and no
  failure;
* a failing test can be quarantined until a date in
  `tests/runner/quarantine.txt` (`rune-test | PATH | QUARANTINE | until
  YYYY-MM-DD: why`): its failure is `QUARANTINED`, reported and no failure,
  until the date, and fails again after it, so that a quarantine is never
  forgotten.

## Expectations

What a suite expects of its tests in some ways (a host's bug, a program
that native code does not run) is a file of expectations, in one format,
read by one engine (`Expectations` in `lib/test/runner`, and
`tests/skipped.sh` for the shell runners):

    WAY-GLOB | PATH-GLOB[::LABEL-GLOB] | CATEGORY | reason

A category means one of four things:

| Meaning | Categories | What it does |
|---|---|---|
| strict | `RUNE-DEV`, `HOST-BUG`, `WIDTH`, `SPEC-AMBIGUOUS`, `WINDOWS`, `EMULATED`, `FAILS` | the test must fail there; a pass fails, and a line that matches no failure in a way that ran is stale |
| lenient | `HOST-FLAKY`, `FLAKY` | the test may pass or fail |
| skip | `HOST-ABSENT`, `XC1-NA`, `XC2-NA`, `UNTESTED`, `UNSUPPORTED` | the test is not run, and is reported as skipped with the reason; a line that names no test is stale |
| quarantine | `QUARANTINE`, with `until YYYY-MM-DD:` | the test runs, and its failure fails nothing until the date; after it the line is stale |

The files stay where they are: `tests/opt-skip.txt`, `tests/windows-skip.txt`,
`tests/portability-skip.txt`, `tests/external/mlton-skip.txt` and
`tests/lib/deviations.txt` are in this format, and `make check` holds each
to parse and to name programs that exist (`expectations/*`).
`tests/basis/deviations.txt` is read by the engine for the Basis suite in
Rune's configurations (`tests/runner/basis.sml`, with run-matrix.sh's rule
that any line explains a failure and a line that explains none is stale),
and by `run-matrix.sh` for the hosts; `tests/basis/law-skips.txt` (lines of
three fields, of every way) by the engine for the laws
(`tests/runner/laws.sml`).

## The three oracles

**The output.** A program under `tests/` runs with `--checked` and its
standard output is compared with its `.expected` sibling; `.args`,
`.vmargs`, `.stdin` and `.exitcode` siblings fix the rest of the run
(`tests/runner/lang.sml`, and `tests/run-tests.sh:6-7,66-74` for the runners
of other machines). This is the ordinary test. Each program is compiled
once by each compiler and run in every way (a VM and its options) that
`make check` has, each run in a directory of its own; `bin/rune-test run
--accept FILTER` writes what the selected tests printed into their
`.expected`, `.cwarn` and error files, to be read line by line.

**The counts.** `runevm --count` prints, at exit, the instructions
executed and the bytes and objects allocated (`runtime/runtime.c:285`). The
numbers are exact, and the same on every engine: the suites check that
the two compilers' bytecodes allocate the same bytes and objects
(the oracle `register` of `tests/runner/oracles.sml`), that the interpreter and every JIT mode report
identical counts (the oracle `jit` of `tests/runner/oracles.sml`), that the 32-bit and the
big-endian VM agree with this machine's to the byte
(`portability/count/*`, `tests/runner/portability.sml`), that the three Windows VMs do
(`tests/run-windows.sh:184-191`), that native code does (`AGENTS.md`, the
native rule), and that the compiler, `runedoc` and the benchmark programs
stay within their budgets (`tests/perf/*.budget`, `make perf-check`,
`tests/perf/run-perf.sh`). Where cycles and seconds are noisy by percents,
a count is a number that either matches or is a bug.

**Byte-identical artefacts.** `make bootstrap` checks that the compiler
compiled by itself reproduces `bin/rune.rbc` byte for byte, and
`check-cross` that all host builds produce the same bytecode for every
test program (`building.md`, *Bootstrapping*). This rests on the compiler
being deterministic: ordered maps, counter-generated stamps, reals passed
through as text.

The rest of this page is about the second oracle, because it is the one
that is easy to break from outside the VM: a count that differs between
two runs of the same program is either a bug in an engine or a difference
in the input, and the input is larger than it looks.

## What the input is

[runtime.md](runtime.md) says the counts depend on the program and its
input alone, not on the machine, the pointer width, the heap size or the
collector's schedule. What the input includes, measured (a 50,000-object
program, `runevm --jit=off --count`, one thing changed at a time):

1. **The program's name and arguments.** `CommandLine.name` and
   `CommandLine.arguments` are strings on the heap, and a string's payload
   is rounded up to 8 bytes ([runtime.md](runtime.md)): the same program
   reached through a longer path allocates 8 bytes more for every 8
   characters of the path, with the same instructions and objects. The
   harnesses therefore run every program from a directory of its own under
   a fixed name (the oracle `jit` of `tests/runner/oracles.sml`: `cd "$out/$name"`, then
   `prog.rbc`), and a count taken by hand with the program's full path is
   not comparable with the harness's. The two sides of a comparison need
   paths of the same length, not only the same file name:
   the oracle `register` of `tests/runner/oracles.sml` ran its two VMs from directories named
   `stack` and `new`, two characters apart, and every program agreed until
   the directory above them got a name five characters longer and one
   program's name crossed a boundary of that rounding (16 bytes then) on one side alone. The current directory's name is the
   same kind of input for a program that asks for it: MLton's `lexgen`,
   `mlyacc` and `vliw` build the names of their inputs from
   `OS.FileSys.getDir ()`, and `vliw` walks that name a character at a
   time, 66 objects for every character of the checkout's path. Their
   counts were those of one checkout until the runner gave them a relative
   directory (`tests/external/mlton-bench/*.sed`).

2. **The kinds of the three standard streams.** A stream over a regular
   file or `/dev/null` has positions and gets the position closures at its
   first use; a pipe, a socket or a terminal has none
   (`lib/basis/runefile.sml:35-56`, `RuneFile.positions`, which asks
   `fileTell` once). Measured: a pipe on standard input instead of
   `/dev/null` is 17 objects, 408 bytes and 18 instructions fewer; a pipe
   on standard error instead of a file, 17 objects, 408 bytes and 12
   instructions fewer; standard output to a file instead of `/dev/null`,
   18 instructions fewer with the same bytes and objects. So a program run
   from a terminal, or with its output through `tee`, does not count the
   same as in a harness. The harnesses fix all three: standard input from
   `/dev/null` unless the test has a `.stdin` sibling, standard output and
   error to files (`tests/run-tests.sh:69-74`, the oracle `register` of `tests/runner/oracles.sml`,
   the oracle `jit` of `tests/runner/oracles.sml`, `tests/run-windows.sh:88-91`). The
   portability runner lets the VMs inherit its own standard input
   (`tests/runner/portability.sml`), which is fine because every VM in
   the comparison gets the same one; that is the rule: both sides of a
   comparison get the same three streams, whatever they are.

3. **The clock.** It reaches the counts in two ways. Through control: a
   program that slices its work by CPU time does more per slice on a faster
   engine, so MLton's `model-elimination` benchmark allocated 79 GB on the
   stock VM and 76 GB on an instrumented VM four times slower, and printed
   a different search. Through output: a printed elapsed time is a string
   whose length follows the value, so MLton's `tensor` allocated 19 objects
   more on the slower VM. Such a program has no count until the clock is
   taken out of it: for a workload, shim `Timer` with a counter that
   advances a fixed amount per check (the census runs advance
   `checkCPUTimer` by 100 microseconds per call, about one inference of the
   timed run, so the sliced search does the same work everywhere) and keep
   every time out of the output. The basis tests that read the clock
   (`tests/basis/time.sml`, `timer_sig.sml`, `date_fmt.sml`) test
   properties of the values, not the values.

4. **Randomness and the file system.** A seeded generator is part of the
   program (MLton's `psdes-random` counts the same everywhere); entropy
   from the system, the order a directory lists its entries in, and the
   contents of a file the previous run wrote are input. A test that needs
   such a thing carries it (`.stdin`, `.args`) or makes it in a fresh
   directory. That a file exists is input too. The compiler refuses an
   output that is one of its sources, and asks by comparing the output's
   `OS.FileSys.fileId` with every source's (`src/driver/main.sml`): where
   the output is not there yet each comparison raises and is handled, one
   object, 32 bytes and four instructions more than where it is. The
   compiler compiling its own 50 files into a new file therefore counts 50
   objects, 1,600 bytes and 200 instructions more than into the file its
   last run left. A harness that compares two runs of the compiler removes
   the output before each (`scripts/census.sh`, `tests/runner/censustrace.sml`).

What was measured and did **not** matter: address-space randomisation,
the environment (an empty one gives the same numbers), whether the VM was
named by an absolute or a relative path, whether an output file already
existed, `--heap-size` (allocation does not depend on collection), and the
JIT tier (the premise of the oracle `jit` of `tests/runner/oracles.sml`).

## Rules for a harness

* Run both sides of a comparison with the same three streams: standard
  input from `/dev/null` or the test's `.stdin` file, standard output and
  error to files. Never inherit a terminal.
* Run from the program's own directory under a fixed name, with the same
  `.args` and `.vmargs`.
* Compare the count line as text after stripping the prefix
  (`sed -n 's/^runevm: count: //p'`, the oracle `jit` of `tests/runner/oracles.sml`) and print
  both lines on a failure, as the oracle `jit` of `tests/runner/oracles.sml` does; a reader can then
  see at once whether the difference is 17 objects and 408 bytes (the
  streams), a multiple of 8 bytes with nothing else (a string's length)
  or something new.
* Run an experimental VM under `timeout` and `ulimit -v`; a runaway
  semispace has taken the machine down before.
* Counts may be taken in parallel and on a loaded machine; times may not
  ([performance.md](performance.md)).
* A program whose count depends on the clock is not a test and not a count
  workload until its clock is shimmed.

## Programs on a terminal

What a program shows on a terminal -- the REPL, a line editor -- is tested
by `tests/terminal` (`make test-terminal`, in `make check`; the plan is
[plans/repl.md](plans/repl.md), D23). `tests/terminal/term.py` starts the
program in a pane of a private tmux server at a given size, types keys
and text at it, resizes it, and waits until the screen matches a pattern
or equals an expected screen. The rules it keeps:

* Wait on the screen, never on time: every `wait` is a pattern with a
  deadline, so a loaded machine makes a script slower and not wrong; a
  `sleep` is only for giving a program the time to do something wrong.
* Type bytes (tmux's `send-keys -H`): tmux takes a lone `;` among its
  arguments for its own separator.
* Compare screens with their trailing blanks dropped, against a file
  reviewed line by line, as an `.expected` file is.
* On Windows, through WSL interop, a program started in a pane gets a
  console of the pane's size (a ConPTY), so `make test-windows` runs the
  scripts marked `# windows` on `runevm.exe` too. Interop delivers no
  console Ctrl-C there; an interrupt is tested on Linux.
* Compare a screen while the program still runs: tmux scrolls the screen
  by a line to say that a pane has died, so a program that ends at once
  is started with something after it that keeps the pane alive.
* After a narrowing resize compare only what the program draws anew:
  terminals that reflow (Windows' console) and terminals that cut (tmux)
  leave the old rows differently.

What `lib/terminal`'s editor draws is also tested without a terminal:
`tests/lib/terminal/edit.sml` gives the bytes its `diff` writes for random
edits at random widths to `Emulator`, a terminal in SML, and checks that
the screen is the next frame (D23's property); it runs on every compiler.

`tests/terminal/ptyraw.py` is the other driver: a pty, exact bytes, and
times to the microsecond, which `scripts/perf-repl.sh` uses for the REPL's
latencies. Times taken on a loaded machine say little; the script prints
the load average with them.

## Harnesses that measure

Two C harnesses measure what a design costs on the machine rather than
what a program prints: `tests/layouts`, the heap-layout roadmap's layouts
(`make check-layouts`), and `tests/gcbench`, the collector roadmap's unit
costs (`make check-gcbench`; [plans/garbage-collector-v2.md](plans/garbage-collector-v2.md),
*The harness*). `make check` runs both but times neither: it holds them to
oracles that do not depend on the machine's speed. Every kernel of the
layout harness must give the same checksum under every layout and heap
size (`tests/runner/heapchecks.sml`); every experiment of gcbench runs at tiny
sizes with its own checks on (`tests/runner/heapchecks.sml`, a second or two):
the copies and marks reach every object, the barriers' remembered sets
find every old-to-young pointer, the sweeps free the dead bytes, the stack
scans agree, and the replay allocators keep every object whole and apart,
against their closed forms and a shadow heap. gcbench reads its counters
in the process with `perf_event_open` and goes on with the TSC where it
may not, so the check needs neither `perf` nor the permission to count.
Their timed runs are each directory's `measure.sh`, alone on an idle
machine and pinned to one core ([performance.md](performance.md); the
READMEs of the two directories).

## An instrumented VM

A build that changes what the VM does per object, for an experiment, keeps
the second oracle as its acceptance test. The census VM of the heap-layout
roadmap widens every object header by a word and hooks allocation, stores
and the collector; it subtracts its extra word from the bytes it counts,
so its `--count` line must equal the stock VM's on every workload, and its
trace must add up to that line (the sum of the recorded sizes equals the
bytes, the number of records equals the objects). On 47 MLton benchmark
programs, the compiler and the perf programs it did, and the mismatches
that turned up on the large programs were all input: a pipe where the
stock run had `/dev/null`, and the two programs that read the clock. None
was the VM. Ported to the word layout for the second-generation
collector's roadmap, where the sum leaves the word's boxes out as `--count`
does, it did the same on 54 traces, and `make test-census` holds it to the
stock VM in every `make check` ([census.md](census.md)). The same
discipline applies to a VM with a new layout: the
objects and instructions of `--count` stay identical across the change,
the bytes move once, and the budgets are re-based in the commit that moves
them ([plans/heap-layout.md](plans/heap-layout.md), *Testing a layout
change*).

## When a count differs

1. Rerun both sides with the same streams, directory and name. A
   difference of exactly 17 objects and 408 bytes per stream is the
   streams; a multiple of 8 bytes with equal objects and instructions is a
   string's length, usually the program's path.
2. If the program reads the clock, take the clock out (above) before
   reading anything else into the numbers.
3. Same VM, different modes: `--jit=off` against each mode of
   the oracle `jit` of `tests/runner/oracles.sml`, which names the mode that disagrees.
4. Different VMs or widths: the layout of a value or an object
   ([runtime.md](runtime.md)); `test-portability` and `test-windows` say
   which VM disagrees with this machine's.
5. Two compilers: the oracle `register` of `tests/runner/oracles.sml` diffs the counts of their bytecodes, and
   `--disasm` shows where the code differs.

## Measuring a collector

A collector is judged by what it costs in time, memory and pauses, which
no count says, so the second-generation collector
([plans/garbage-collector-v2.md](plans/garbage-collector-v2.md), D1) is
measured against today's copier on a fixed set of workloads, with the
counts and the outputs as the oracle that it changed nothing else.

**The evaluation set** is `scripts/gc-eval.tsv`: the runs, their groups
and the groups' weights, fixed before any result was in (the roadmap's
*The workloads*). The bootstrap (with and without the JIT), `compile-sigs`
and `runedoc-page`; MLton's benchmarks, the 35 of the normal tier and the
14 of the GC-stress tier over 2 GB (`tests/perf/mlton-bench.txt`); the
lazy programs and the collector's named programs of
[examples/benchmarks](../examples/benchmarks/README.md), `binary-trees` at
depth 18; the latency workloads (`latency-ring` and `latency-map` with 10
MB, 100 MB and 0.93 GB live, `latency-static-map` with 200 MB); and Rune
compiling MLton. Groups weighted 0 0 0 are extras: the compiler from the
default 4 MiB heap, `compile-sigs --jit=off`, the strict twins of the lazy
programs, the static map at 20 and 800 MB.

`scripts/gc-eval.sh CANDIDATE BASELINE` runs the set on both VMs, which
must take `--gc-log` ([runtime.md](runtime.md), *The collector's log*):
round by round, each run on one VM and then on the other, in an order that
alternates with the round, each under `ulimit -v` and `timeout`, `perf
stat` and `/usr/bin/time`, from its own directory with its standard input
fixed and the compiler's output file removed before it (the rules above).
Each run is scored by its round with the least task-clock, as candidate /
baseline: **T** the task-clock, **M** the peak resident memory, **P** the
mean of the ratios of the longest pause, the 99th-percentile pause (a
pause under 1 ms counts as 1 ms) and 1 - MMU at 10 ms (at least 0.01). A
group is the geometric mean of its runs, and each score the geometric mean
of the groups weighted by the set; the M and P columns sum to 95, a slip
found after the set was fixed, so the scores divide by the weight present,
and the report says so. `scripts/gc-eval-score.py` prints the runs, the
worst cases (the five highest ratios of each score, and every run more than
1.10 in T or M, which D1 forbids) and the scores, and lists as problems
every run that did not exit 0, a program of the catalogue that did not
print PASS, any standard output or compiler output that is not the
baseline's, and any run whose bytes and objects allocated (the log's end
line) differ from the others': a collector does not change what a program
allocates.

```sh
scripts/gc-eval.sh bin/runevm-new bin/runevm                 # the set, 3 rounds
scripts/gc-eval.sh --only boot-default,latency --rounds 1 NEW OLD
scripts/gc-eval.sh --candidate-opts '--heap-fill 75' bin/runevm bin/runevm
GC_EVAL_LOCK='flock /tmp/rune-timed' scripts/gc-eval.sh NEW OLD
scripts/gc-eval.sh --score --out tests/out/gc-eval           # score again
```

The set takes about 30 minutes at three rounds on the reference machine
(15 a VM, half of it the GC-stress tier and the 1 GB runs, which are run
once), and the preparation a few more: the catalogue's programs compiled by
`bin/rune -O2 --lint` into the output directory (`tests/out/gc-eval`),
MLton's by `tests/external/run-mlton-bench.sh --prepare` from `MLTON_BENCH`
(their runs are left out where it is missing). `--extras` adds about three
minutes. Rune compiling MLton is part of the set but runs only with
`--mlton-compile`: about 10 minutes a VM, 12 GiB of address space (the heap
capped at 5 GiB), so 20 GB of free memory, from MLton's sources at
`5fe943391` in `MLTON_SOURCES` with the order of its files in
`mlton-rune.txt` (`scripts/setup-mlton.sh DIR` makes them). Times need the machine to themselves: `GC_EVAL_LOCK` is a
command prefix under which each round is made, let go for a minute between
rounds so that others waiting for it have it, and a run waits until its
ulimit and 8 GB more are free (`GC_EVAL_MARGIN`). After an interruption,
`--resume` with the same options makes only the runs that are missing.

**Pauses** come from the log by `tools/mmu.py LOG`: the pauses (a collection
that grows the heap is two passes, one pause), their longest, mean and
percentiles and a histogram, the collector's share, the heap and the peaks,
and the minimum mutator utilisation (the least share of any window left to
the program; Cheng and Blelloch, PLDI 2001) at windows of 1 to 200 ms, on
two clocks: the monotonic wall clock of the log's `t_ns` (never the
program's `Time.now`, which a virtual machine may step), and the
instruction clock, where each collection falls at its instruction count
and only the pauses are timed, which removes the mutator's own noise.
`--json` and `--row` are for scripts; `--self-test` checks the MMU against
closed forms and a brute-force scan.

**The 32-bit address space**: `scripts/gc-probe32.sh` grows a program's live
data on `bin/runevm32` until the heap cannot grow, under a 2 GiB limit and
without one, and reports the most live data a collection completed with
(the copier: 255 and 512 MiB, where D1 asks for 768 MiB and 1.5 GiB);
`--latency` adds the latency window at its 32-bit size, 50,000 messages.
About half a minute.

## Windows text boundaries

`make test-windows-text` is the focused Unicode and long-path suite, included
in `make test-windows`. It needs both MinGW toolchains and Windows execution.
The native helper creates and inspects fixtures with wide APIs; SML probes
exercise each VM, including fork from a Unicode executable, directory and
stream recovery under a long path, and native compilation of `λ.sml`.
Logs are in `tests/out/windows-text`. Each worktree stages its own fixtures
on NTFS using `tests/windows-dir.sh`; a WSL sandbox that blocks interop must
run this target outside that sandbox.

Native host laws use `bin/rune-laws-hosts [--compare] [HOST...]` and the
`test-laws-hosts` runner tier. The shared `MatrixModel`, `MatrixProbe`,
`MatrixHost` and `SmlScan` modules own configuration identities, capability
probes, compiler diagnostics and source dependencies. Every selected host has
collection and comparison jobs; MLKit jobs share the matrix pool.

`LAWS_HOST_TIMEOUT` bounds program execution (default 600 s). Linked
compilation has its own `LAWS_HOST_COMPILE_TIMEOUT` (default 600 s); the
former driver left these compiler calls unbounded. The default memory cap
is 8192 MiB. `LAWS_PROGRAMS` selects generated ASCII program names through a
bounded GNU grep PCRE adapter and must be a single-line expression. Empty
selection uses every program. The adapter is required only for that option.
The source scanner handles strings and nested comments independently of Rune.

The official SML/NJ32 110.99.9 Word64 startup defect is recorded as property
framework unavailability, with a result for every selected law and a named
skip. The Python host-law driver remains during full shadow reconciliation;
the part-two roadmap records the remaining validation.

The documentation consistency checks use `bin/rune-doc-check` and are named
`documentation/{features,signatures,claims,notes,annotations,faults}` in the
runner. `make check-docs` also checks generated pages and lint with runedoc.
Signature and annotation generators write private output; SML compares it
with the committed files. Generation remains a separate Make operation.

`bin/rune-doc-check mutants [-j N] [-n PER_FILE] [FILTER]` samples the same
14 Basis sources and evenly spaced mutation sites as the former driver.
Each target has a baseline dependency, each mutant has a collection and a
verdict case, and the final report depends on collection. `SURVIVED` fails its
named verdict case while the complete results and summary remain available
in `tests/out/mutants`. The former script exited successfully for survivors;
this stricter exit behavior makes the adequacy result usable in automation.
`STILLBORN` means an ordinary compiler diagnostic; a failed producer, missing
bytecode, controller crash or failure before the first law fails the job.
The property seed and environment are inherited; the default law idle limit
is 30 seconds and the sample count is 20 per file.
