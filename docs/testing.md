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
removed as they end, and the last five completed runs are kept. Retention
leaves active and interrupted runs alone, so concurrent invocations cannot
delete each other's output. A `running` marker becomes `complete` only after
the final reports are closed; interrupted runs need explicit cleanup. The wall time of each
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

`runner/check-requirements` guards the portable tier against native Windows
requirements, retains the Windows installer's platform selections, and
keeps the independent notebook peers in `check`. A private Python fixture
also verifies that `doctor` rejects missing notebook modules before a suite
starts.

`--affected` keeps the tests that cover what changed since `HEAD`
(`--since REV`, `--changed FILE`): each group of tests names the paths it
covers (`covers:GLOB`, in `tests/runner/*.sml`). Compiler, runtime, Basis,
runner-library, Makefile, build/generation-tool and script changes select every
test in the requested tier. These broad inputs remain broad even where another
group also names a narrower path. An unclassified path also keeps every test;
documentation and individual fixture changes use their explicit coverage.


The programs of `tests/lang` and `tests/errors` are the runner's own tests
(`compile/COMPILER/NAME`, `lang/WAY/NAME`, `errors/COMPILER/NAME`;
`tests/runner/lang.sml`; each program is also checked by `bin/rune
--typecheck-only`, `lang/typecheck/NAME` and `errors/typecheck/NAME`, which
must judge it as the compile does -- accepted with its `.cwarn`, refused
with its `.expected` in the first line -- but where a sibling says
otherwise: a `.typecheck-error` beside a program of `tests/lang` that the
check refuses, the text of the first line of what it says, or a
`.typecheck-ok` beside one of `tests/errors` that it accepts, what it says
(nothing, mostly); these are the corners where the check types a functor's
application by the Definition and a compile does not yet,
[language.md](language.md), *Functors*), and so are the Basis Library suite's in Rune's four
configurations and the examples of its documentation
(`basis-compile/COMPILER/TEST`, `basis/CONFIG/TEST`, `basis/CONFIG/@stale`,
`basis-examples/NAME`; `tests/runner/basis.sml`) and the laws of its
documentation (`laws-compile/NAME`, `laws/NAME@STRUCTURE`, each under a
watchdog that skips a case that hangs or runs out of memory and goes on;
`tests/runner/laws.sml`), and the differential checks, each program a job
that compares what it compiles and runs across levels, engines, builds and
hosts (`levels/*`, `register/*`, `jit/*`, `units/*`, `units-stack/*`,
`positions/*`, `cross/*`, `reproducible/*`, `bootstrap/*`, and the
generated programs of functors, `functors/*`, below;
`tests/runner/oracles.sml`), and the tools' suites (`ir/*`, `doc/*`, `lib/*`,
`flexrec/*`, `compiler/*`, `limits/*`, `gc-log/*`, `colour/*`, and the scenarios of
`tests/deps`, `tests/dynamic`, `tests/buildfile` and `tests/units` as
`scenario/*`; `tests/runner/tools.sml`), and the protocol suites (`repl/*`,
`diagnostics/*`, `serve/*`, `repl-protocol/*`, `dap/*`, `kernel/*`,
`incremental/*`; `tests/runner/protocols.sml`). Scenario and protocol policy
is Standard ML. Heap, benchmark, native, terminal and low-level checks also
have individual SML jobs. Make builds prerequisites; the three retained
compatibility jobs for generated docs, benchmark coverage and ISA checks
invoke SML tools. Jobs declare shared resources and producer dependencies
to the same scheduler. Five
canaries, tests that fail on purpose (an exit with 1, a run past its time,
a crash, a flood of output and a leaked process), pass only when the
runner sees each fault for what it is; they run in every `make check`,
since the runner is built by the compiler it tests.

The completed script migration is recorded by
[the part-two roadmap](plans/unit-testing-part2.md) and
`tests/runner/migration.tsv`: 282 retired files and nineteen retained
bootstrap/setup, installer and independent-oracle/peer exceptions.
`runner/migration-inventory` rejects unassigned
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
`test-native-asan`. The Basis stress selections use the SML matrix controller.

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
Absent/stale standalone archives use `bin/rune-measure census`; the routine
checks also use SML producers. The JIT analysis tool
uses the SML measurement CLI; objdump is the instruction decoder capability.

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

The `ffi-runtime` capability reflects `RuneForeign.available()` in the
coordinator VM and gates tests that execute generated native calls. Build
that VM with `FFI=yes` to enable it. It is separate from `libffi`, which
checks development files for independent C ABI oracles. Generator parsing,
publication, host comparisons and Windows CLI checks remain available when
native calls are disabled. An explicit `RUNEVM` override does not redefine
the coordinator's capability. With `FFI=no`, enabled-call jobs omit their
`check` tag because that configured feature is absent; explicit native-call
tiers still name `ffi-runtime` and report an unsupported capability. The
runtime's disabled branch remains in `check` and verifies unavailability.
Strict missing-capability policy stays unchanged.

A test names the capabilities it needs of the machine (`Test.requires`):
`pty`, `python3`, `cc`, `qemu`, `windows`, and each host
(`mlton`, `smlnj-legacy`, `smlnj32`, `smlnj-dev`, `polyml`, `mlkit`), each
a probe and an install hint in `tests/runner/main.sml`, the hints
`scripts/doctor.sh` gives. `bin/rune-test doctor [FILTER]` probes what the
selected tests need and says how to get what is missing. A run skips a test
whose capability is missing, with its hint; the tier `check` (and
`--strict`) fails it instead, since `make check` must be complete.
`RUNE_TEST_WITHOUT=pty,qemu` takes those as missing, to see what a machine
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
read by `Expectations` in `lib/test/runner`;
`bin/rune-suite skip [--reasons] FILE [WAY]` exposes the skip-only view:

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
and by `bin/rune-matrix` for the hosts; `tests/basis/law-skips.txt` (lines of
three fields, of every way) by the engine for the laws
(`tests/runner/laws.sml`).

## Generated functor programs

`bin/rune-functor-gen` (`tests/runner/functorgen.sml`) draws programs of
the module language's hard shapes, with `lib/test/property`, and holds the
compiler to one property: a program prints the same compiled whole and in
units (`--units --no-cache`), with functors compiled as functions and their
applications expanded (`--functors=functions --datatype-tags=sorted-x`,
always under `--lint`) and as today's copies; `--units --whole` makes the
whole compile's bytes (S42 of
[plans/functors-units.md](plans/functors-units.md)); and so it does with
some of its functors marked `--inline-functor`, and under a small
`--functor-budget`, which leaves some applications calls. A program's units
are its files: a prelude of signatures and leaf structures, its functors (a
unit each, or several to one), its applications and its prints, so that a
functor is declared in one unit and applied in another, or in its own.

The shapes, each a part of the generator drawn at random and combined:
functors applied in functors' bodies, to a depth of four, to the parameter,
an adapter or a literal of it, a structure of the top level, an inner
instance or another application, the instances shown, hidden or partly
hidden by the result signature, in `local` or opened; datatypes in bodies
over the parameter's types -- plain, mutually recursive with a member
hidden, with `withtype`, polymorphic, local, replicated from the
parameter's datatype spec -- with constructors of tuples, records,
parameter types, functions and reals; leaf structures whose type is of
every layout; `type`, `eqtype` and datatype specs (matched by a datatype
whose constructors are in another order), `where type`, `sharing`, the
derived forms of parameters and none, opaque and transparent ascription,
named signatures; polymorphic values and type constructors in parameters
and results, equality on the parameter's and the body's types, `''a`;
exceptions in bodies (each application's its own, or the parameter's or an
inner instance's again), refs and effects (each application runs them once,
in order), substructures in parameters and results. What a program prints
makes each visible: every instance's results, matches on constructors,
exceptions handled across instances, counts and equalities. A program is a
plan of choices made well typed by construction (an argument that does not
match a parameter falls back to a literal that does), so a failure the
property finds is shrunk to a small program.

`functors/@generated` runs 20 programs from seed 1, a minute or two;
`functors/@regressions` runs each program of `tests/functors` (in the form
`bin/rune-functor-gen show` prints: each unit after a line `(* unit FILE
*)`, and a last line of the modes' options) in every mode.
`tests/functors/known.txt` lists the failures found and not yet fixed, a
line each: a mode, a text of the failure's message, and why. A failure a
line covers is counted and passes, in both jobs; and each line must be met
by a program of `tests/functors`, so that once the compiler is fixed the
line is stale and goes. A failure one file shows is a program of
`tests/lang` too, with its `.expected` from the flag off, and its failing
tests in `tests/runner/quarantine.txt` until fixed.

By hand, longer: `bin/rune-functor-gen check --seed S --seeds K --count N
--known tests/functors/known.txt --rune bin/rune-mlton --out DIR` runs K
runs of N programs from the seeds S on (`bin/rune-mlton`, MLton's build of
the compiler, makes the same bytes about three times as fast). Each failure is
shrunk and kept in `DIR/failures/seedS-caseN`: its units, `program.sml`
(which `bin/rune-functor-gen run FILE` runs again) and `modes.txt`, what
each mode compiled with and printed; the run goes on with the next seed.
`bin/rune-functor-gen show --seed 0xHEX --size N` prints the program of a
failure's replay token `HEX:N`, as it was drawn.

## The three oracles

**The output.** A program under `tests/` runs with `--checked` and its
standard output is compared with its `.expected` sibling; `.args`,
`.vmargs`, `.stdin` and `.exitcode` siblings fix the rest of the run
(`tests/runner/langchecks.sml`, shared by local and Windows ways). This is the ordinary test. Each program is compiled
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
(`tests/runner/windowschecks.sml`), that native code does (`AGENTS.md`, the
native rule), and that the compiler, `runedoc` and the benchmark programs
stay within their budgets (`tests/perf/*.budget`, `make perf-check`,
`bin/rune-budget`). Where cycles and seconds are noisy by percents,
a count is a number that either matches or is a bug.

**Byte-identical artefacts.** `make bootstrap` checks that the compiler
compiled by itself reproduces `bin/rune.rbc` byte for byte, and
`check-cross` that all host builds produce the same bytecode for every
test program (`building.md`, *Bootstrapping*). This rests on the compiler
being deterministic: ordered maps, counter-generated stamps, reals passed
through as text.

The example inventory covers top-level sources and sources one directory
below `examples`. `tests/runner/exampleprojects.sml` distinguishes standalone
programs from `.build` applications and their shared fragments. Example job
and artifact names include their directory, so root `hello.sml` and SDL's
`hello.sml` cannot collide. Unknown build entrypoints or unclassified project
members fail the inventory audit.

`check-cross` and `check-positions` compile the Win32 mock application through
`examples/win32/mock.build`. The generated providers have focused compilation
gates: `make test-sdl-hosts` generates the complete SDL binding and compares
bytecode for both SDL examples across all seven Rune compiler builds;
`make test-win32-hosts` does the same for the native Win32 application using
both Windows ABI profiles and the pinned original SDK headers. These gates
compile the actual `.build` entrypoints without opening GUI libraries. Runtime
and real-desktop acceptance remain the separate SDL/Windows suites. Project
fragments are never advertised as standalone programs.

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
   error to files (`tests/runner/langchecks.sml`, the oracle `register` of `tests/runner/oracles.sml`,
   the oracle `jit` of `tests/runner/oracles.sml`, `tests/runner/windowschecks.sml`). The
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
   the output before each (`bin/rune-measure census`, `tests/runner/censustrace.sml`).

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
by `tests/terminal` (`make test-terminal`, in `make check`; see
[plans/repl.md](plans/repl.md), D23). The scripts run through bin/rune-terminal on the runtime's
Pty interface. The SML interpreter supplies input, key and paste bytes, watches
Emulator frames, resizes the terminal and checks child status. Each scenario
owns its history/configuration directories, raw trace and final screen.
The runtime capability pty is independent of an external terminal program.
Windows scenarios run natively on ConPTY for both VM widths; rune-repl.cmd is
also exercised. The raw-mode restoration scenario reads actual termios flags
after normal return, exceptions, fatal errors, SIGTERM and SIGHUP.

The scenario language retains start, send, keys, paste, wait/waits/gone,
resize, expect, capture, exited and sleep. Exact expect waits for the requested
frame under a finite deadline, so a partial asynchronous redraw is not a
wrong final screen. Styles are compared through canonical SGR captures of
Emulator cells; OSC titles/marks are consumed without becoming screen text.

The raw route is bin/rune-terminal raw COLS ROWS SCRIPT -- CMD...; it preserves
write/until/quiet/winch/mark/report/dump and reports milliseconds separately
from deterministic byte assertions. It drains output while sending bounded,
nonblocking input chunks. The runner's own display is captured through a PTY
and ordinary streams, including progress, failures, resize and the final frame.
Human raw-event logs use SML string escapes; the REPORT label/number/ms fields
retain their measurement grammar. Raw bytes are kept separately in artifacts.
Faults exercise wrong frames, lost input, bad sizes, crashes after output,
floods, background children, raw-mode restoration and closed sessions.

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

`bin/rune-measure gc-eval CANDIDATE BASELINE` runs the set on both VMs, which
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
and the report says so. `bin/rune-measure gc-eval-score` prints the runs, the
worst cases (the five highest ratios of each score, and every run more than
1.10 in T or M, which D1 forbids) and the scores, and lists as problems
every run that did not exit 0, a program of the catalogue that did not
print PASS, any standard output or compiler output that is not the
baseline's, and any run whose bytes and objects allocated (the log's end
line) differ from the others': a collector does not change what a program
allocates.

```sh
bin/rune-measure gc-eval bin/runevm-new bin/runevm                 # the set, 3 rounds
bin/rune-measure gc-eval --only boot-default,latency --rounds 1 NEW OLD
bin/rune-measure gc-eval --candidate-opts '--heap-fill 75' bin/runevm bin/runevm
GC_EVAL_LOCK='flock /tmp/rune-timed' bin/rune-measure gc-eval NEW OLD
bin/rune-measure gc-eval --score --out tests/out/gc-eval           # score again
```

The set takes about 30 minutes at three rounds on the reference machine
(15 a VM, half of it the GC-stress tier and the 1 GB runs, which are run
once), and the preparation a few more: the catalogue's programs compiled by
`bin/rune -O2 --lint` into the output directory (`tests/out/gc-eval`),
MLton's by `bin/rune-external benchmark --prepare` from `MLTON_BENCH`
(their runs are left out where it is missing). `--extras` adds about three
minutes. Rune compiling MLton is part of the set but runs only with
`--mlton-compile`: about 10 minutes a VM, 12 GiB of address space (the heap
capped at 5 GiB), so 20 GB of free memory, from MLton's sources at
`5fe943391` in `MLTON_SOURCES` with the order of its files in
`mlton-rune.txt` (`bin/rune-build setup-mlton DIR` makes them). Times need the machine to themselves: `GC_EVAL_LOCK` is a
command prefix under which each round is made, let go for a minute between
rounds so that others waiting for it have it, and a run waits until its
ulimit and 8 GB more are free (`GC_EVAL_MARGIN`). After an interruption,
`--resume` with the same options makes only the runs that are missing.

**Pauses** come from the log by `bin/rune-measure mmu LOG`: the pauses (a collection
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

**The 32-bit address space**: `bin/rune-measure gc-probe32` grows a program's live
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
The `windows/text/*` SML jobs own compilation, staging and verdicts, with a
shared preparation dependency and separate native-oracle/four-VM cases.
Logs are in the run's `windows/text` directory. Each worktree stages private
fixtures on NTFS using `bin/rune-windows directory`; a WSL sandbox that blocks
interop must run this target outside that sandbox. `platform/windows-text-faults`
rejects empty/mislabeled output, failure after PASS and nonzero/timeout exits.

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
skip. The legacy Python host-law driver is retired. The part-two roadmap records
full comparisons, controlled host configurations and the observed native GC
failures separately. A failed law program is recorded and collection continues
with later programs; controller errors fail comparison and cannot become passes.

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

Benchmark correctness and deterministic-budget drivers use
`bin/rune-bench-check` and `bin/rune-budget`. `suite NAME` selects the typed
case contract, `catalogue` accepts the former profile/config/filter options,
`smoke` runs routine correctness, `extra` includes the independent peers and
negative scenarios, and `inventory` runs the preserved upstream fixtures.
Console output now uses the common runner's per-case report and events.
Original script names and blob IDs in benchmark-cases.json are provenance.
The three baseline failures (fluid float formatting, pidigits5 and zarith
27-digit layout) remain failures; all 267 old/new output streams match.

`bin/rune-scenarios SUITE [--rune BIN]` selects deps, buildfile, dynamic, units,
install or dist. Installation also accepts repeated `--host NAME`; Make's
install tier retains bytecode, MLton and SML/NJ. All stage prefixes are private.
Distribution assertions read archive metadata in SML and use independent
ELF/PE fixture bytes. Compression decoding uses gzip/unzip, declared as
capabilities. The Windows installer case uses `--no-register` and is gated
on Windows interop. It belongs to `test-windows`, the `windows`/`vm` profiles
and `nightly`; it is also available through `test-dist`. The portable
`check` tier retains the archive, metadata, binary-header, POSIX installer
and archive-fault cases, without requiring Windows.


The incremental cache controller is `bin/rune-incremental`. `scenarios`
accepts a scenario filter; `one LABEL COMPILER` is the inventory's isolated
case action. `mutate` retains project, compiler, Basis-copy and repository
history modes. The new generator is version 2, uses SplitMix64 and the same
thirteen edit families, and deliberately starts a new deterministic sequence.
`mutate --replay-v1` replays the frozen legacy Python seed-1 trace: all 70
receipts preserve success, rebuild count and reuse across changed units.
Failure snapshots keep source order, edits and both diagnostics. `plant`
manufactures stale or old-version cache entries independently of Rune.

`bin/rune-external regression DIR`, `benchmark [OPTIONS]`, and `probe DIR...`
run externally provisioned corpora. The regression route preserves expected
exception text and skips; benchmark mode retains prepare, explicit count
updates, data staging and VM options. Results use the common SML supervisor
and receipts, with original program verdict lines printed after collection.
The pinned MLton compiler scenario remains an explicit expensive command,
`bin/rune-incremental mlton CHECKOUT [OUT]`, with its memory availability guard.


The full Basis controller is SML: bin/rune-matrix retains configurations,
standalone program/input/data modes, timing, refresh and resolution output.
The --one CONFIG TEST route selects an exact name. Explicit CLI selections
fail when a required compiler cannot start. Collection, comparison, stale
deviations and reports are separate inventory cases; missing structures are
recorded as skips. Interactive sessions are distinguished by the actual
compiler, so Rune compiling a host library still has compile-only type checks.
Reports include dropped sources, timing phases and compatible timings.tsv
records. Bytecode imports accept legacy CRC and version-2 keys, invalidate
changed inputs and preserve reuse when only the execution VM changes.


Language/runtime platform workers are bin/rune-suite and bin/rune-windows.
The former retains --rune/--vm/--out/--skip/--one/--update/-j and filtering;
skip [--reasons] FILE [WAY] exposes Expectations. The latter provides
directory, vm --vm BIN --def FILE and the Windows language selection.
Windows ways share local fixture judges, strict refusal cases and cross-VM
count/image oracles. Build preparation and consumers have explicit dependencies;
unavailable selected targets fail, while capabilities retain their named skips.

Each count/image oracle invocation atomically reserves private staging under
its endpoint directory. Parallel cases and widths therefore use separate
`prog.rbc` and image files. `platform/oracle-staging` forces a second oracle
between the first copy and execution: the planted shared-directory allocator
must fail its counter comparison, and the production allocator must pass.


GMP configuration, dependency, CPU-family, build-mode, download, installation
and cross-platform controllers are routes of bin/rune-intinf. The root
check runs the bounded offline download and native dependency cases.
Binary-mutating build-modes and prepare-cross are explicitly selected,
exclusive jobs. prepare-cross preserves hashed GMP-free payloads and platform
configurations before rebuilding enabled VMs; cross --sml-vms DIR tests every
required platform, arithmetic backend and saved-image consumer/limit pair.
Production download policy has an offline CLI seam; SML drives actual child
processes and corrupt/partial archive fixtures without importing Python mocks.



Protocol drivers use bin/rune-protocol-check: repl NAME [--update], dap,
kernel, notebook and interop LIB COMPILER VM OUT. DAP and kernel accept
--windows; the root inventory retains separate pipe and connection ways.
Protocol assertions and Windows staging are SML. Python capabilities belong
to the independent Jupyter/ZMTP peers. The `check` tier requires
`jupyter_client` and `zmq` for its independent notebook peer; on Ubuntu use
`python3-jupyter-client` and `python3-zmq`. `make doctor` checks the imports
with the same `python3` used by the peer. Direct controller use can still
skip that peer when its modules are unavailable. Faults
exercise malformed headers/signatures, wrong reply IDs, premature exit and
lost interrupts, with kernel shutdown and leak detection during failures.

The measurement and analysis controllers use `bin/rune-measure`; the modes and
instrumentation contracts are listed in [tools/measure/README.md](../tools/measure/README.md).
P2.14 retires 43 shell, Python and AWK controllers. `make bench`, `bench-count`
and `bench-stats` use the public SML tool. Timing selections are explicitly
exclusive (`bin/rune-test --tier measurement-runs`) and stay outside `make check`.
Independent MMU scan vectors and measurement fault assertions remain ordinary
checks. Captured reports keep their historical measurement command labels;
current CLI examples use the SML modes. Generator and build/package ports
completed P2.15 and P2.16; their contracts and evidence are in the roadmap.

Post-bootstrap generators use `bin/rune-generate`, with standalone inventory
queries through `bin/rune-inventory`. Their modes and data/oracle contracts are
listed in [tools/generate/README.md](../tools/generate/README.md). Include Rune in
matrix selections when auditing unused deviations: its actual labels distinguish
an unavailable host case from a stale expectation. The generator acceptance
record retains full source/record comparisons, concurrent isolated runs, poisoned
input refusal and all generated-library results. Build/package bootstrap conversion
and whole-project acceptance completed P2.16 and P2.17.

Production build and packaging policy uses `bin/rune-build`, compiled by the
native MLton before target GMP configuration or VM creation. Its shared models
also build as Rune bytecode for the retained runtime SDK. See
[tools/builder/README.md](../tools/builder/README.md) for modes and bootstrap
requirements. P2.16 retires all eight production scripts; the current ledger has 282
retired targets and nineteen explicit bootstrap/installer/oracle exceptions.
Make's unit-bootstrap, template and Int64 comparisons also use SML jobs.
`make test-int64` preserves both VMs and all four JIT modes, on a word past 63
bits in a home and on `tests/lang/rt.div_constant.sml` (division by a constant,
functors-units M1), each compiled at `--int-bits=64`. Final global
acceptance is recorded by P2.17 of the continuation roadmap.

The final recipe audit exposes C fixture execution under `low-level/*`.
`low-level/basic` preserves VM refusals and the original heap test;
`low-level/heap-hooks` preserves the default, GC-bit and card variants.
`low-level/jit` checks encoder independence, executable memory, the C
encoder and macro-assembler subjects (and `divconst`, the steps of a division
by a constant run against C's division) and deep recursion in all/tiered/call-return
modes. The recursion cases retain a 1 MiB OS stack through a thin `ulimit`
adapter; SML owns arguments, deadlines and byte comparisons. The focused
selection passes 20/20 including canaries and eight literal guard fault vectors.
Make retains the C compilation graph and the compatibility target names.

Final acceptance on 2026-10-22 passed the default `make check JOBS=8` on clean
`4f9065f5b`, without a `RUNE` override: 19,238 PASS, two documented native
interrupt skips and zero failures. The complete `all,xc2` matrix passed 7716
cases with 858 explicit unavailable skips, including all eighteen strict
stale-deviation audits and its report. Platform acceptance covers actual
Windows/ConPTY/DAP/kernel, portability, register/native sanitizers, GC stress
and all six native library hosts. All twelve public controller payloads match
native MLton and self-hosted compilation byte for byte. The
[P2.17 acceptance record](plans/unit-testing-part2.md#p217-final-acceptance-2026-10-22)
identifies exact tested states, retained failures and receipts, Windows
transport reruns, existing host deviations and the unvalidated live HOL
benchmark. The historical timing comparison above is a separate experiment.

The subsequent rebase onto `origin/master` at `05ecacb9c` retires the newly
added Windows Unicode shell driver too. Combined source `77ad74a60` preserves
all 19,240 previous check IDs and adds 91. Its default full check reports
19,328 PASS, two native-interrupt SKIP and one intermittent
`terminal/edit-complete` resize failure; an exact rerun passes, while one of
ten further repetitions fails. The full result remains recorded as FAIL.
Windows language/runtime/ConPTY/Unicode passes 2367/2367. Two Windows Basis
collections hit WSL temporary-directory lookup timeouts; their collections
and comparisons pass with the supported directory override, and all four
strict audits plus the complete 948-result report pass with zero unexplained
failures. Windows DAP and kernel sessions also pass. The
[rebase record](plans/unit-testing-part2.md#rebase-onto-windows-unicode-master-2026-10-22)
keeps the original failures and rerun receipts separate.
