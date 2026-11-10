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

Every compile a test makes is linted at level 2, every pass
([ir.md](ir.md), *Levels*): `bin/rune-test` sets `RUNE_LINT=2` for itself
and its jobs unless it is set already, and the compiler, the REPL and the
compiler library then check what every pass makes as `--lint` does, and
stop at the first breach, which is a bug of the compiler. That includes
the check of the register code (`RegVerify`, at level 1; [ir.md](ir.md),
*The register target*), whose own negative tests are
`register/@regverify-*`: the eleven corruptions its switch
`RUNE_REGVERIFY_INJECT` makes, each refused with its own message;
`register/@call-index` holds tier 2 to testing `CALL`'s function index in a
register it trusts; the link's check of the units' interfaces is held to its refusals by S80 of
`tests/incremental/SCENARIOS.md`, and a compile takes from a cache only
the entries checked at its level (S81; [units.md](units.md), *The cache*);
the check of the stack code's, at level 2, are `stack/@rbccheck-*`, six
corruptions `RUNE_RBCCHECK_INJECT` makes and one at a link of units, each
refused with its own message ([ir.md](ir.md), *The stack target*); and
`AstLint`, the check of the elaborated Core (level 2; [ir.md](ir.md),
*AstLint*), whose are `compiler/astlint-faults`: the twenty corruptions
`RUNE_ASTLINT_FAULT` makes of what it reads.
`RUNE_LINT=1` lints at the boundaries alone, `RUNE_LINT=0` runs only what
is always on, and `RUNE_LINT=` (empty) what each program runs by itself:
level 0 in `rune`, 1 in the REPL and the compiler library. One tier lints
deepest, at level 3, Mid's text read back after every stage: `make
test-ir` (`ir/*`). The budgets (`bin/rune-budget`) count the compiler as
it is shipped, at level 0, and clear `RUNE_LINT` for what they count. A
check never changes what the compiler makes, so that a test linted tests
the compiler a user runs: `levels/*` compiles every program of
`tests/lang` and `tests/perf` to the register bytecode at level 2 and at
level 0, at `-O2` and in units, and fails where the two differ by a byte,
a unit's files and their bases too; `compiler/*` compares a program's
units with `--mid-roundtrip` and without; and `Pass.checkAt` stops a
compile whose check moved a counter of the compiler's names
([ir.md](ir.md), *Options*). Every rule of every lint has a negative
test ([ir.md](ir.md), *Tests*): `faults/STAGE:KIND` (tier `test-ir`)
compiles `tests/compiler/faults.sml` with a fault made on purpose after
the stage (`RUNE_FAULT=STAGE:KIND[@N]`, for the tests alone) and wants that
stage's lint to refuse it with the rule's message, and `compiler/lint-rules`
compiles the compiler's internals with `tests/compiler/lint-rules.sml`,
which gives each rule no fault reaches -- of LambdaLint, MidLint, LowLint,
`midcanon`'s renaming, the guard of the counters, the levels, LowLint's
ways and the invariant of results in globals -- what breaks it, by hand.
The Basis and the compiler library of `lib/cache` are compiled with
`--lint` (`make basis-cache`).

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
| `hs` | rhc's tests (*rhc's tests* below): its programs, round trips and conformance table, and the runner's own checks of that machinery |

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
(nothing, mostly); none is left since functors are compiled once and every
mode types an application alike, [language.md](language.md), *Functors*),
and so are the Basis Library suite's in Rune's four
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
`flexrec/*`, `overloading/*`, `compiler/*`, `limits/*`, `gc-log/*`, `colour/*`, and the scenarios of
`tests/deps`, `tests/dynamic`, `tests/buildfile` and `tests/units` as
`scenario/*`; `tests/runner/tools.sml`), and the protocol suites (`repl/*`,
`diagnostics/*`, `serve/*`, `repl-protocol/*`, `dap/*`, `kernel/*`,
`incremental/*`; `tests/runner/protocols.sml`), and rhc's (`hs/*`, *rhc's
tests* below; `tests/runner/hslang.sml`, `tests/runner/hsroundtrip.sml`,
`tests/runner/hsconformance.sml`). Scenario and protocol policy
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
`tests/portability-skip.txt`, `tests/external/mlton-skip.txt`,
`tests/lib/deviations.txt` and `tests/cross/deviations.txt` are in this
format, and `make check` holds each to parse and to name programs that
exist (`expectations/*`). `tests/cross/deviations.txt` is check-cross's
(`crossCheck` of `tests/runner/oracles.sml`): `HOST | CHECK | HOST-FLAKY |
reason`, a build of check-cross and the name of a check of `cross/*`, for a
host compiler's fault that comes and goes (SML/NJ's 32-bit collector), since
Rune's sources are not changed for one host ([building.md](building.md)).
Such a build may fail the check, which says so on a line `HOST-FLAKY`, not
a failure, and still compares every other build's bytes; where the build
compiles, its bytes must be the others' as any build's. Only `HOST-FLAKY`
lines are deviations there, and a line that names no build or no check
fails `expectations/cross-deviations`; `runner/cross-deviations` holds the
rules to planted lines.
`tests/basis/deviations.txt` is read by the engine for the Basis suite in
Rune's configurations (`tests/runner/basis.sml`, with run-matrix.sh's rule
that any line explains a failure and a line that explains none is stale),
and by `bin/rune-matrix` for the hosts; `tests/basis/law-skips.txt` (lines of
three fields, of every way) by the engine for the laws
(`tests/runner/laws.sml`).

## rhc's oracles and corpus

rhc, the Haskell 98 compiler of `docs/plans/language/haskell98.md`, is judged against oracles and a corpus that
stay outside the tree (M3, D52). The corpus's licences, its manifests and its compat layer are
`tests/hs/corpus/` (README.md there): the programs are read through `RUNE_HS_CORPUS`, a directory holding the trees
that `tests/hs/corpus/trees.tsv` pins, but for the 188 of D56's set, vendored in `tests/hs/corpus/vendored/` under
a notice each, the nearest `LICENSE` or `PROVENANCE` above them: 45 with their trees' licence files (GHC's
testsuite's BSD-3, jhc's MIT), and 143 that no licence covers with a `PROVENANCE` written here (their upstream and
commit, the upstream paths, the authors and origin their headers name, what notice there is, and the date). The
owner's rules: code not under CC0 lands with its licence beside it, and code under no licence with a `PROVENANCE`
beside it. The oracles are GHC 9.4.7 with
a strict shim, Hugs, nhc98 and MicroHs (`tests/hs/oracles/README.md`: each oracle's variable, pin and recipe, and
the shims, which the run builds). The family is `tests/runner/hssource.sml`, `hscorpus.sml`, `hsoracles.sml` and
`hschecks.sml`:

- `hs-oracles/ORACLE/conformance`, `judge-SET`, `run-SET` and `@stale`, in the tier `nightly`, each requiring its
  oracle's capability (`hs-ghc`, `hs-hugs`, `hs-nhc98`, `hs-microhs`) and `hs-corpus`: they reproduce E7's 82
  conformance tests against what their suites expect, and E8's verdicts and run set against what E8 recorded. A
  difference is a failure unless a line of `tests/hs/oracles.txt` explains it, in the format of *Expectations*
  with the outcome first in its reason (`hugs | conformance98/layout/do::conformance | HOST-BUG | reject: R56:
  ...`); `@stale` fails a line that explains no failure of a job that ran. A disagreement on a conformance test
  cites its reading of the Report (`tests/hs/readings.md` from R55).
- `hs-corpus/data`, `source` and `faults`, in `check`: the data is whole and agrees with itself and with
  `oracles.txt`, nothing lands under `tests/hs/corpus/` but its data, each of E7's hard cases has a reading, the
  source rewrites do what E8's did on planted text, and the harness fails where it must on fake oracles.

A job is also a command: `bin/rune-test hs-oracle conformance hugs`, `hs-oracle judge ghc nofib-2019`,
`hs-oracle run nhc98 jhc`, `hs-oracle stale ghc`, `hs-oracle ghc-shim`; `RUNE_HS_OUT` moves their output from the
run's directory.

rhc goes through the same corpus (`tests/runner/hsrhccorpus.sml`, `hslazyports.sml`), in the tier `nightly`:

- `hs-rhc-corpus/m13-SET` and `rest-SET`, needing `rhc` and `hs-corpus`: each program of
  `tests/hs/corpus/accept.tsv`, prepared in the variants the oracles judge it in and last under D35's
  `--dotted-names`, through `bin/rhc --typecheck-only`, which stops after names and fixity until M13 lands and then
  checks types.
  `m13-SET` are the rows of M13's done-when, both judges accepting and nothing needed (815 in all, in `h98`);
  `rest-SET` the others. A program both judges accept and rhc refuses is a finding: it fails its job unless a
  line of `tests/hs/rhc-corpus.txt` names its cause, in the format of *Expectations* with the outcome first
  (`rhc | ghc/should_compile/x::check | RUNE-DEV | reject: ...`); what rhc says of a program the judges do not
  both accept is kept in the job's results and judged by nothing. `@stale` fails a line that explains no
  refusal of a job that ran.
- `hs-lazy-ports/PORT`, needing `rhc` and `rhc-compiles` (which compiles and runs hello, so held until rhc
  compiles): the Haskell beside each `-lazy` port of `examples/benchmarks` that `tests/hs/lazy-ports.tsv` marks
  `ready` (GHC prints nofib's fixture in fast mode, and its imports reach the Report), prepared as the corpus is,
  compiled by rhc and run on `bin/runevm` with nofib's arguments and input, against nofib's output, the fixture
  the SML port is validated against. The manifest says why each other port is held; a finding is a line of
  `tests/hs/rhc-corpus.txt` (`rhc | lazy/PORT::run | ...`).
- `hs-corpus-run/ID` (D56, B): each of D56's 188 compiled by rhc and run in D56's three ways (`test`, `register`,
  `register-opt`), its output E8's expected one (the same, the same words, or numbers equal to about five digits)
  and its status 0; all 188 vendored and in `check`, all held while rhc runs no program (the row `prog.main.value`
  Planned). `hs-rhc-corpus/vendored-SET`, in `check`, a job a set, puts the 45 under a `LICENSE` through
  `--typecheck-only` as the nightly jobs above put the whole corpus, and `hs-rhc-corpus/provenance-SET`, nightly,
  the 143 under a `PROVENANCE` (ruling 46: D56 puts the 188's runs in `check`, not a names job, and the nightly jobs
  above check the 143 too). `hs-corpus/vendored` (nightly, with the trees) holds `tests/hs/corpus/vendored/` to the
  trees' bytes at their commits, and `hs-corpus/data` to the vendored programs' files and notices and nothing more:
  it refuses a file with no `LICENSE` or `PROVENANCE` beside it or above it, or under another notice than its row of
  `licences.tsv` names, and a `PROVENANCE` that does not name its tree's upstream and commit or quote the owner's
  rule. `bin/rune-test hs-corpus-vendor` makes it again from the trees, leaving each `PROVENANCE` as written.
- `hs-corpus/faults` holds the first to a fake rhc. Commands: `bin/rune-test hs-rhc-corpus m13 ghc-legacy`,
  `hs-rhc-corpus stale`, `hs-lazy-ports calendar-lazy`; `RUNE_HS_RHC`, `RUNE_HS_RUNEVM`, `RUNE_HS_RHC_TXT` and
  `RUNE_HS_LAZY_PORTS` stand in other tools and files.

## Generated functor programs

`bin/rune-functor-gen` (`tests/runner/functorgen.sml`) draws programs of
the module language's hard shapes, with `lib/test/property`, and holds the
compiler to one property: a program prints the same compiled whole and in
units (`--units --no-cache`), at `-O0`, where every application is a call
of its functor's function, and from `-O1`, where the expansion gives
applications their copies back (always under `--lint`); `--units --whole`
makes the whole compile's bytes (S42 of
[plans/functors-units.md](plans/functors-units.md)); and so it does with
some of its functors marked to be inlined (`inline functor` in a build
file the runner writes beside the units), and under a small
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
hidden, with `withtype`, polymorphic, local, replicated from the parameter's
datatype spec -- with constructors of tuples, records, parameter types,
functions and reals; leaf structures whose type is of every layout; `type`,
`eqtype` and datatype specs (matched by a datatype whose constructors are in
another order), `where type`, `sharing`, the derived forms of parameters and
none, opaque and transparent ascription, named signatures; polymorphic
values and type constructors in parameters and results, equality on the
parameter's and the body's types, `''a`, a polymorphic datatype spec;
exceptions in bodies (each application's its own, or the parameter's or an
inner instance's again), refs and effects (each application runs them once,
in order), refs, arrays and vectors of the parameter's types and the body's,
declarations of a body that branch, bind a refutable pattern or close over
the parameter's values, substructures in parameters and results. What a
program prints makes each visible: every instance's results, matches on
constructors (an alias's values matched by the constructors of what it
names, and a replicated datatype's by its argument's), exceptions handled
across instances (two applications of one functor among them), counts and
equalities. A program is a plan of choices made well typed by construction
(an argument that does not match a parameter falls back to a literal that
does), so a failure the property finds is shrunk to a small program.

`functors/@generated` runs 16 programs from seed 1, a minute or two;
`functors/@regressions` runs each program of `tests/functors` (in the form
`bin/rune-functor-gen show` prints: each unit after a line `(* unit FILE
*)`, and a last line of the modes' options) in every mode.
`tests/functors/known.txt` lists the failures found and not yet fixed, a
line each: a mode, a text of the failure's message, and why. A failure a
line covers is counted and passes, in both jobs (a mode the lint refuses so
is held to the rest of the property at `-O0`); and each line must be met
by a program of `tests/functors`, so that once the compiler is fixed the
line is stale and goes. A failure one file shows is a program of
`tests/lang` too, with its `.expected` from `-O0`, and its failing tests
in `tests/runner/quarantine.txt` until fixed.

By hand, longer: `bin/rune-functor-gen check --seed S --seeds K --count N
--known tests/functors/known.txt --rune bin/rune-mlton --out DIR` runs K
runs of N programs from the seeds S on (`bin/rune-mlton`, MLton's build of
the compiler, makes the same bytes about three times as fast). Each failure
is shrunk and kept in `DIR/failures/seedS-caseN`: its units, `program.sml`
(which `bin/rune-functor-gen run FILE` runs again) and `modes.txt`, what
each mode compiled with and printed; the run goes on with the next seed.
`bin/rune-functor-gen show --seed 0xHEX --size N` prints the program of a
failure's replay token `HEX:N`, as it was drawn.

## rhc's tests

rhc, the Haskell 98 compiler of [plans/language/haskell98.md](plans/language/haskell98.md),
has its programs under `tests/hs`, run by the machinery that runs
`tests/lang` (`tests/runner/lang.sml`): a suite there is a value of the
record `Lang.suite`, which says where its programs are and what their files
end with, who compiles and runs them, and its tags, and `Lang.tree` makes its
jobs. Rune's is `Lang.rune`; rhc's is `HsLang.rhc` (`tests/runner/hslang.sml`).

* **Programs.** A program is a file `NAME.hs` or `NAME.lhs`, or a directory
  `NAME` with a `Main.hs` or `Main.lhs` in it, whose other modules rhc finds
  beside it. Its siblings are named from `NAME` in both cases, beside the
  file or the directory, and are Rune's: `.expected`, `.cargs`, `.args`,
  `.vmargs`, `.stdin`, `.exitcode`, `.stderr`, `.stderr-head`, `.cwarn`,
  and `.typecheck-ok` beside a refused program that `--typecheck-only`
  accepts: a check takes a file as the module it holds, and only a compile
  asks that it be `Main` (the roadmap's D53; `prog.main.name`).
  Two programs of one name in a directory (a `.hs` beside a `.lhs`) are a
  failure of `hs/runner/programs`.
* **Three directories.** `tests/hs/lang` holds the programs compiled and
  run, `tests/hs/errors` those refused, with the text of their `.expected`
  in the first line of what rhc says, and `tests/hs/accept` those only
  checked, which `bin/rhc --typecheck-only` accepts saying nothing (or their
  `.cwarn`). The jobs are `hs/compile/COMPILER/NAME`, by `bin/rhc
  --target=stack` (`stack`) and `bin/rhc` (`register`);
  `hs/errors/register/NAME`; `hs/lang/WAY/NAME` in the three ways of the
  roadmap's D56, `test` (`bin/runevm-stack`), `register` (`bin/runevm`) and
  `register-opt` (tier 2); `hs/lang/typecheck/NAME`,
  `hs/errors/typecheck/NAME` and `hs/accept/NAME`. They need the capability
  `rhc` (`bin/rhc`); where there is no program there is no job. With
  `--accept`, the way `register` writes `.expected`.
* **Tiers** (the roadmap's D56, B; the lead's ruling 45). A program of
  `tests/hs/lang` runs in `check` in the three ways, with its two compiles
  and its check, unless `tests/hs/lang-nightly.txt` names it (a program
  over D56's second, with its measured time), when all its jobs are
  `nightly`; `hs/errors/register/NAME` is `check` and `hs/errors/typecheck/NAME`
  `nightly`; `hs/accept/NAME` is `check`. The register way and the refused
  programs are also `quick`.
* **What they cover.** `covers:` tags for `tests/hs`, `lib/language/haskell`,
  `src/rhc`, `share/rhc` and `rhc.build`, so that `--affected` runs rhc's
  tests alone for a change there, and everything for a change to the
  compiler, as for any test.
* **The runner's own suite.** The same machinery is held to its work without
  rhc: `hs/runner/...` is a suite of the same kind over `tests/hs/runner`,
  whose compiler and VM are a stub, commands of `bin/rune-test`
  (`hs-stub-compile`, `hs-stub-run`). It compiles and runs a `.hs`, a `.lhs`
  and a program of two modules in a directory, one that exits with a
  status and one that warns, refuses one and checks one. The stub's
  bytecode is what the program's `putStrLn`s print, so a program that the
  runner hands the wrong file prints something else. A stub VM that prints
  nothing must fail every program for its output (`hs/runner/silent/NAME`,
  whose judge is the run's turned round), as the oracle `jit` fails a run
  that prints nothing where it should.
* **The oracle `jit`** (`tests/runner/oracles.sml`) takes the compiler and
  the path a program's siblings are named from (`bin/rune-test jit-one-with
  COMPILER BASE SOURCE`), and runs rhc's programs nightly, interpreted and in
  every mode of the JIT (`hs/jit/NAME`), beside D56's three ways in `check`.

**Round trips** (the roadmap's D28; `tests/runner/hsroundtrip.sml`). On every
file of `tests/hs/lang`, `tests/hs/accept` and `tests/hs/roundtrip`
(`hs/roundtrip/rhc/PATH`, from `tests/hs`, with the explicit print's two tests,
in `check`; `hs/roundtrip/rhc-printers/PATH` with the implicit and exact
prints', `nightly`):

* the **tree test:** the file printed with explicit braces parses to the
  tree the file does, its locations erased;
* the **token test:** the tokens of that print are the tokens the layout
  algorithm makes of the file, but for empty items (a `;` after `{` or `;`,
  or before `}`) and a trailing comma before `)`. A parser that drops a part
  of the tree prints without it, and the reparse agrees with itself, so the
  tree test passes; only this test sees it;
* both again on the **implicit print**, with layout, since a printer that
  prints only braces never exercises the layout algorithm;
* the **exact test:** the exact print of the file is the file, byte for byte;
* and, where the tool has a generator, the **generated trees:** from a fixed
  seed, each printed tree parses to the tree it was printed from, and goes
  round as a file does (`hs/roundtrip/rhc/@generated`).

A tool is the commands that do these, each given a file and printing to
its standard output: `print`, `implicit`, `exact`, `tokens` (one token a
line, a token of the layout algorithm as `{`, `;` or `}`), `tree` (the tree
as text, locations erased) and `generate SEED COUNT DIR`, which writes
`DIR/gen-K.hs` and its tree `DIR/gen-K.tree`. rhc's are options of `bin/rhc`
(`HsRoundTrip.rhc`), turned on as its driver gains them. A command that
refuses a file, or prints nothing for one that is not empty, fails the
test. The harness is held to its tests by a stub of a toy syntax of words
(`hs-stub-syntax`), which passes on `tests/hs/runner/roundtrip`
(`hs/roundtrip/stub/...`) through the shell as rhc's commands run; with a
fault planted it must fail the test that sees it (`hs/roundtrip/@faults`):
a parser that drops `where`, the token test and not the tree test; a printer
that drops parentheses, the tree test; an exact printer that drops a
comment, the exact test; a tree command that prints nothing; an implicit
printer that swaps two items. `hs/roundtrip/@normalise` holds the
normalisation to examples. The stub's commands run in the runner's process
in those two checks and its generator's, since a command of
`bin/rune-test` starts in about half a second.

**The conformance table** (the roadmap's D53 and D38;
`tests/runner/hsconformance.sml`). `tests/hs/conformance.tsv` has a row for
each clause of the Haskell 98 Report: E9's 3,901, each with its `id`,
`section`, `statement`, `class`, `test` (`accept`, `reject`, `run` or
`none`) and `how`, from a reading of the text that no program has checked
yet, and three columns of rhc's: `status` (`Supported`, `Partial` or
`Planned`, the words of [language.md](language.md)), `reading` (the R
numbers of the readings that concern the row: E9's R1 to R54, which the
roadmap's *What the Report says* cites, and those after, each with its
heading in `tests/hs/readings.md`, where the oracles part from the Report)
and `deviation` (empty, or the program that pins it, `DIR/NAME` from
`tests/hs`). The table lands as data: only errata and
readings edit it, and no script lands to make it (`runner/migration-inventory`).
Its text is the December 2002 Report with the published errata applied
(D38): `tests/hs/errata.tsv` lists the page's 18 errata, each with the rows
it edits (`rows`), those it adds (`adds`) and, where it touches none, why.
A program of `tests/hs/lang`, `tests/hs/accept` or `tests/hs/errors` names
the row of its name's id, the part before its first `_`, as a program of
`tests/lang` does, and on its first line, `-- rows: ID ...`, the further
rows it covers (a production's rows, a definition's), the readings it pins
(`R2`) and `deviation` where it pins one. Each direction is a failure of
`hs/conformance/table`:

1. a row whose test is `accept`, `reject` or `run` and that is not
   `Planned` has a program of its class that names it: `tests/hs/accept` or
   `tests/hs/lang` for `accept`, `tests/hs/lang` for `run`,
   `tests/hs/errors` for `reject`; or, where it deviates, its pin, which is
   of the other class (a row the Report accepts and rhc refuses, R1's);
2. what a program names is a row, of a test its directory serves, but the
   row whose deviation it pins;
3. a row whose test is `none` says why in `how`;
4. a row with a reading, once it is not `Planned`, has a program that names
   it and pins each of its readings, and a program pins only the readings of
   the rows it names; a row with a deviation names its pin, a program that
   names the row and says `deviation`, and has its note in
   `tests/hs/deviations.tsv` (its ground, one of D38's four -- wrong,
   contradictory, ambiguous, cannot be implemented -- and why), and a pin
   and a note are each a row's;
5. a program of `tests/hs/errors` has an `.expected`, rhc's own message, so
   that a program refused for another reason fails.

With those, the table's form: its header and the errata list's, no row or id
twice, the classes, tests, statuses and sources of E9's columns, readings R1
to R54 or headed in `tests/hs/readings.md`, every row accounted for (3,901
and what the errata add), and every row whose text names an erratum listed
by one, and back. A program's first line ends at Haskell's first newline, a
return, a line feed or a form feed.
`hs/conformance/faults` plants each breach in a private tree and wants it
refused, and a tree that keeps every rule, with a row of each class
supported and a deviation pinned, accepted. A row leaves `Planned` when its
program exists and the judges have seen it (roadmap, M19); the roadmap's
G2 is the state in which none is `Planned`. Until then the program's jobs,
and its round trips, are listed and held (`SKIP`, not run: a program whose
every row is `Planned`), so that a program can land with its clause before
rhc passes it, and a row's leaving `Planned` is what turns them on.

A clause program cites its clause in a comment at its head (`-- Report
2.4: ...`), after its first line if that names rows, and is a whole program,
well typed where the clause does not say otherwise, so that it stays judged
the same as rhc grows from a parser to a compiler. Before it lands it is put
to the oracles of D52 (GHC with the strict shim, Hugs `+98`, nhc98 `-98`,
MicroHs as a smoke test); where they part from the Report, rhc follows
D38's rule and the disagreement is recorded as a reading.

**The syntax of Haskell 98** (`lib/language/haskell`'s `syntax.build`, the
roadmap's M11; [tests/hs/syntax/README.md](../tests/hs/syntax/README.md)).
rhc's commands for the round trips are `--print`, `--print-layout`,
`--print-exact`, `--dump-tokens` and `--dump-ast --no-spans`, and its
generator is `bin/rune-hs-syntax generate-files`, the syntax generator of
D55. Besides the clause programs of the parser's rows,
`tests/hs/roundtrip` holds the parser's own fixtures: a file for each part of
the grammar and the lexical syntax, the crafted cases of the roadmap's E10
that the syntax accepts, and, for rows of the layout rules and the lexical
syntax, a file with its expansion written by hand beside it (`NAME.braces`).
What those runners do not hold the syntax to is `tests/runner/hssyntax.sml`'s,
the jobs `hs/syntax/*` (`make test-hs-syntax`) of `bin/rune-hs-syntax`: the
first line of each diagnostic of the lexer, layout and the parser and of
the cases the syntax refuses (`tests/hs/syntax/errors`); the tokens of the
layout algorithm against the expansions; 2,500 trees of the syntax generator
printed both ways and read back in one process; the parser's mutants, E10's
five, which the tree test cannot see and the token test must, and a lexer
that drops a comment, which only the exact print sees, each built and run
over `tests/hs/roundtrip`; the cost of a token in `runevm --count`'s
instructions, bytes and objects, within `tests/hs/syntax/budget`; and,
nightly where GHC is installed (the capability `ghc`), GHC's dump of each
file's parsed tree against its dump of the file's explicit print
(`hs/syntax/ghc`; E10's 1,662 files of the corpus too, with
`RUNE_HS_SYNTAX_GHC_LIST` and `RUNE_HS_SYNTAX_GHC_ROOT`), its known
differences in `tests/hs/syntax/ghc-dump.tsv`.

**Names, modules and fixity** (`lib/language/haskell`'s `names.build` and
`src/rhc`'s graph and names, the roadmap's M12;
[tests/hs/names/README.md](../tests/hs/names/README.md)). `--typecheck-only`,
which judges an accept program, and a compile, which judges an error program,
check as far as rhc goes: the program's modules, found from the file given and
in `share/rhc/haskell98` (the wrapper `bin/rhc` passes `--share`), their
exports and scopes, every name, fixity, and (M13) kinds, types and classes. `tests/runner/hsnames.sml`'s jobs
`hs/names/*` compare `bin/rhc --dump-names` of each fixture of
`tests/hs/names` with its expected files: the Report's 20 modules whole,
against E16's export pairs, fixities and instances; E16's fixtures under both
fixpoints (`--names=least|greatest`); a program's own `Char`; fixity by
entity; a cycle of three signed modules; a dotted module name. And
`hs/names/mutants` (nightly) builds the dump with one edit at a time, each of which a
fixture must catch: the greatest fixpoint for the least, a hidden module
importable, fixity read before names.

**Kinds, types and classes** (`lib/language/haskell`'s `types.build`, the
roadmap's M13 and M14; [tests/hs/types/README.md](../tests/hs/types/README.md)).
The same runner's jobs `hs/types/*` compare `bin/rhc --dump-types` of each
fixture of `tests/hs/types` under both settings of `--cycle-default` with its
expected files: the Report's libraries checked as one unit, a cycle of modules
with unsigned bindings and a type group across it, D30's readings of `default`
and Rule 2 in a cycle, and deriving, each derived instance with the context the
checker infers. `bin/rhc --dump-evidence` prints a program's evidence records
(HsEvidence), what desugaring (M15) and HsLint (M16) read, and `bin/rhc
--dump-derived` the methods of its derived instances, which HsDerive makes as
trees inside the checker (D33's C) and the checker checks as a user's.

**The saved world** (`src/rhc/world.sml`, the roadmap's D45, its B;
`tests/runner/hsworld.sml`). `bin/rhc` restores `bin/rhc.img`, rhc with its
library read, named and checked, saved as a VM image as `bin/rune-repl.img`
is, and reads and checks only a program's own modules against it; `make
bin/rhc` makes the image again when rhc, the VM or a file of `share/rhc`
changes, and `bin/rhc` restores it only where `bin/rhc.img.identity`, the
identity of the rhc that made it, is `bin/rhc.identity`, `bin/rhc.rbc`'s.
`bin/rhc --whole` reads and checks the library too, the reference, as does
any option that changes the library's reading, and `bin/rhc --world` says
which a check takes. The jobs `hs/world/*` hold the two to printing alike:
`image` that `bin/rhc` goes from a world this rhc made, newer than every
file of `share/rhc`; `accept/K-of-4`, `errors/K-of-4` and `lang/K-of-4`
every program of the directory checked both ways, with its `.cargs`, to the
same standard output, standard error and status; the first shard of each in
make check, the others nightly; `bin/rune-test hs-world-one KIND NAME`
judges one. A mutant's tree (`hs-mutants`) has no image, so a mutant goes
the whole way.

**HsLint** (`lib/language/haskell`'s `hslint.build` and `src/rhc/lint.sml`,
the roadmap's M16 and D54; [tests/hs/hslint/README.md](../tests/hs/hslint/README.md)),
the independent check of rhc's types, as AstLint is Rune's. Its first part
is a second inference: a transliteration of Typing Haskell in Haskell in the
form its 11.6.3 calls conformant, with kinds and dependency groups recomputed
and D32's readings of the monomorphism restriction and defaulting, which
shares nothing with the checker but the renamer. rhc runs it through
`Pass.checkAt` at level 2, after names and the checker (`--lint=2`, and
`RUNE_LINT=2`, which `bin/rune-test` sets), so a program the checker accepts
and HsLint refuses fails any compile of it, `lint after hslint: FILE:LINE:COL: WHY`;
`bin/rhc --dump-hslint FILE.hs` prints what it infers, each binding's type,
the kinds, the derived instances' contexts and the defaults it chose, or
`REFUSED` and why. `tests/runner/hslint.sml`'s jobs `hs/hslint/*` hold it to
what it must find: `dump/NAME` each fixture of `tests/hs/hslint` against its
expected dump, reviewed line by line (under `--cycle-default=scc` and with
the library's unsigned bindings, `--dump-hslint=library`, where it has those
files), then the checker on it at level 2, which must accept what the dump
infers and refuse what it refuses while HsLint replays its records, so that
rhc's mutants of the checker (HK01 to HK05) fail a fixture's job;
`accept/K-of-4` and `lang/K-of-4`, every program of `tests/hs/accept`
and `tests/hs/lang` inferred, whatever its rows' status, since the second
inference waits on no stage of the compile; and `errors/K-of-4`, every
program of `tests/hs/errors` whose row is of the classes static, prelude or
library refused, by HsLint or before it. A directory's programs are judged
in four jobs, each every fourth program and a line FAIL for each it fails,
since a job of `bin/rune-test` costs several times what rhc does on one
program; `bin/rune-test hs-hslint-expect KIND NAME` judges one. The first of
the four is in `check`, the other three `nightly` (D56; the lead's ruling 45). A program on
which the two part is listed in `tests/hs/hslint/disagreements.tsv` with
why, and its job holds the disagreement to still being there, so that a fix
on either side is seen. The same jobs hold the two judges to one verdict on
every program, the checker alone (`--typecheck-only --lint=off`) and
HsLint's second inference alone (`--dump-hslint`): where they part, the
program is listed in `tests/hs/hslint/judges.tsv` with why, and held there
the same way. HsLint also holds the inference to a record's
claims of it, in the dump's form (`--hslint-claims=FILE`), each difference
refused by the rule it breaks, `[rule1] ...` (`bin/rhc --hslint-rules`
names them); the checker's evidence records are its claims too (M13).
Where the checker accepts a program, HsLint replays Faxén's rules on its
evidence records (D31): Rule 1 by his `bindg` with Definition 2, every
dictionary by his `dict tuple`, `dict var`, `dict inst` and `dict super`
against HsLint's own classes and instances, an instance's superclasses'
dictionaries and its methods' types, a class's methods in its
declaration's order (`[slot]`, its dictionary's layout), and rhc's own rule
for a cycle of modules (`[scc]`); then holds the records, read as claims, to the second
inference. A derived instance, which HsDerive makes as the tree a user would
write (M14), is checked as any instance is: the second inference types its
methods at the head and the least context it derived itself (10.1, the data
type's context with it), and replay reads their records and their methods'
types. `faults` holds each rule to refusing its fault, as
`astlintFaults` holds AstLint's: `tests/hs/hslint/faults.hs`, its records
and its own expected dump, is accepted, and with `RHC_HSLINT_FAULT=RULE`,
which reads the first claim or record RULE checks corrupted, refused with
`[RULE]`.

**rhc's library** (`share/rhc/haskell98`, the roadmap's M17 and M18: the
Report's 20 modules in its own layout, its errata and rhc's overlay applied,
with the Report's code as printed in `pristine/`; D36, D37, D38).
`tests/runner/hslibrary.sml`'s jobs `hs/library/*` hold it to the Report
while no compiler runs it: `overlay`, each module's tokens against
`pristine/`'s, a line at a time, white space and comments dropped, every
line where they differ an entry of `overlay.tsv` marked applied, and every
file the Report has no text of an entry's `new:`; `pristine`, the printed
code byte for byte as `pristine/MANIFEST.tsv` records it; and `report`,
`bin/rhc --dump-names` of the Report's 20 modules against E16's table of the
Report (`tests/hs/library/report.names`: 663 export pairs, 35 fixities, 164
instances), changed exactly by the lines of `tests/hs/library/overlay.names`,
each with its entry.

**rhc's mutants** (D55; `tests/runner/hsmutants.sml`, the list in
`tests/runner/hsmutantlist.sml`). The machinery of the compiler's mutants
with rhc in Rune's place: a mutant is exact edits of a file of `rhc.plan`,
built by the good Rune from that plan's files
(`CompilerMutants.buildFrom`) into an rhc of its own, with no stage two, as
rhc never compiles itself. Each names the jobs that must fail on it, jobs
that run (rows out of `Planned`). Its job builds it, says how many of rhc's
outputs (tokens, tree, check) on an even sample of `tests/hs`'s programs
differ from the good rhc's, and runs the jobs it names in a tree of links to
the root in which `bin/rhc.rbc` is the mutant's: `CAUGHT` by the first that
fails, else `UNCAUGHT`, or `UNEXERCISED` where no output differs, or
`STILLBORN`, each but the first a failure, as is a named job that does not
run. `make check` holds the list to the sources (`hs-mutants/prepare`, and
the first mutant's `built-ID`, a canary); `make test-rhc-mutants`, nightly,
builds the others and judges them
(`HS_MUTANTS=HL01,HP02` for some; `bin/rune-test hs-mutant-tree ID` builds a
mutant's tree for a job to be run against it by hand). The first fourteen
seed rhc's lexer, its literate reader, its layout and its parser, CoreLint,
Core's interpreter and Core's text reader, these last seen by `hs/core`'s
jobs. F's parser
mutants (`tests/runner/hssyntax.sml`) are the in-process kind.

**rhc's metamorphic relations** (D55; `tests/runner/hsmeta.sml`). Pairs of
programs that must behave alike, compiled by rhc and run, their exit and
output compared: each program of `tests/hs/lang` against its print with
every block in braces (`hs/meta/braces`, 2.7 and 9.3), that print printed
again by layout (`hs/meta/layout`), and the program with `import Char ()`
added (`hs/meta/import`, 5.3.1); and the pairs written by hand in
`tests/hs/meta`, `NAME.hs` and `NAME.pair.hs`, the relation first in NAME:
`rename` (bound variables renamed, 3.3, 3.12) and `reorder` (declarations
reordered, 4.5.1 and the top level). Two more are made from each program:
`hs/meta/reorder`, its top-level blocks (runs of lines between blank ones) in
the reverse order, and `hs/meta/split`, the program split into a module
`Lib` holding every block but `main`'s and a `Main` that imports it (5, the
multi-module form of a joined program; none is made where a `default`
declaration or a name qualified by `Main` would change the program). A pair
is held while its program's rows, or the rows its relation cites, are
`Planned`; what runs today is rhc's names on both programs of the two new
relations, on an even sample of 30 (`hs/meta/names/*`; `reorder` in `check`, the others
nightly, as the mechanical relations but `braces` are): as many scope errors
in the program's own modules, and Main's exports, fixities and instances the
same (a split's moved to `Lib`). Renaming bound variables mechanically waits
for a dump of rhc's binding sites; the `rename` pairs are by hand.

**rhc's sharing budgets** (`tests/runner/hsperf.sml`, `hs/perf/NAME`). A
program of `tests/hs/perf` that costs far more when what the Report leaves
unsaid is not shared (a section's operand, a file read on demand, an array's
components) has `NAME.budget`, rhc's policy: lines `a:`, `b:` and `ratio:`.
Compiled by rhc and run twice under `bin/runevm --count`, on the line a and
the line b as its standard input, the first's instructions are at most the
ratio times the second's: a ratio separates linear from quadratic and holds
on any machine. Held while the row the name gives is `Planned`.

**Renaming, by rhc's names.** `bin/rhc --dump-binders FILE` prints each local
name of the program's own modules, a line for each binding site (`BIND`) and
use (`USE`): its renamed name and its bytes. `hs/meta/rename` renames each to
`x'k` where every occurrence's span is the name itself; a name whose
binding's span covers more, as a function binding's head does, is left.

**rhc's interpreter against its VM** (`tests/runner/hsinterp.sml`,
`hs/interp-vm/NAME`, nightly). Each run program of `tests/hs/lang` through rhc to
Core, run on Core's interpreter (`bin/rhc --lint=3 FILE`) and compiled through
Mid to the VM (`bin/rhc --lint=2 FILE -o OUT`, `bin/runevm OUT`), with its
`.stdin`: the VM prints what the interpreter printed and ends as it did, every
bottom one bottom. A program the interpreter alone can run says so on a line
`-- vm: no: REASON`, as `hs/core`'s `; vm: no:` does. Held while the
program's rows are `Planned`; M15's done-when and G1 rest on it.

**rhc's reducer** (`tests/runner/hsreduce.sml`). `bin/rune-test hs-reduce
FILE -- CMD...` shrinks a Haskell program while CMD, given a candidate's
path as its last argument, exits 0: delta debugging over the top-level
blocks, the header kept, then over the lines, every candidate a whole file.
It writes FILE.reduced. `hs/reduce/@self` reduces 64 lines to the one
declaration that a predicate on rhc's parser and a marker wants.

**Bottom probes** (D55; the roadmap's *Bottom probes*). Run programs of
`tests/hs/lang` named `ROW_probeN`: a marker printed, then a term that
applies a Prelude function to partial values, element by element, so that
the output says how far it got and `.exitcode` whether it then failed. The
expected output is what the Report's own definition of the function, copied
under another name, gives; GHC, Hugs and nhc98 agree on each. They are
clause programs, held as the rest.

**rhc's generated programs** (D55's third generator;
`tests/runner/hsgen.sml`). Well-typed, terminating programs drawn from a
seed, with Int, Bool and `[Int]` values, top-level functions, `let`, `case`,
lambdas, the list functions and `const e undefined`, each with the output its
own evaluator gives. `hs/generated/@parse` puts 32 through rhc's parser in
`make check` now; `hs/generated/@run` (16 from seed 1, `check`) and
`hs/generated/@nightly` (400, `nightly`) compile and run them, held until
the rows they need are out of `Planned`. `bin/rune-test hs-generate SEED`
prints a program and its output; `hs-generated FIRST COUNT` runs a range.

## rhc's Core

rhc, the Haskell 98 compiler of the haskell98 roadmap
([plans/language/haskell98.md](plans/language/haskell98.md), M8), has its
tests under `tests/hs/core`, in `tests/ir`'s form, run by the family
`hs/core/*` (`tests/runner/hscore.sml`; tier `test-rhc`, part of `make
check`; `make test-rhc`), beside the families of `tests/hs` (*rhc's tests*,
above), which may take them in. A test is a file of Core text whose first line says
what to do with it: `; run: FLAGS`, run by `bin/rhc --lint=3 FLAGS
--read-core FILE` on Core's interpreter, its standard output held to
`NAME.expected` and its status to `NAME.exitcode` (0 where there is none),
and a run that prints nothing a failure, whatever is expected; `; dump:
FLAGS`, the same for a dump of a stage; `; fail: MESSAGE`, refused with
MESSAGE on standard error; `; refuse: FLAGS | MESSAGE`, refused with MESSAGE
when compiled through Mid with FLAGS, which make a fault of Core to Mid on
purpose (`--fault`, the roadmap's *rhc's mutants*): a suspension in a typed
slot, which MidLint refuses at the boundary into Mid, and a force made a
cast, which form C's lint refuses as a force forgotten (`fault-*.core`);
`; forces: N FLAGS`, compiled with the dump of Core to Mid, which holds N
`thunk_force` nodes, one for each force of Core, which the file counts by
hand (`forces.core`). `--accept` writes the `.expected` files, to be read
line by line. At level 3 rhc prints what it read, reads it back and
prints it again, so print, read, print is the identity on every test.
`tests/hs/core/lib/base.core` is what the run tests share, read before each
by its flags. A run reads `NAME.stdin` as its standard input where there is
one, and a test with a line `; files: own`, which writes files, runs each
time in a directory of its own.

rhc's runtime (`CoreRuntime`, the roadmap's M17: the Report's `prim*`,
written in Core) has `prims-*.core`, Core's primitives on their edges
(`Int` at 63 bits, `Integer` across the edges of IntInf's small range,
`Double`, `Float` rounded to binary32), and
`runtime-*.core`: strings unpacked lazily and at once (D24's A and B, which
print the same), files, standard input read across the edge of a chunk, the
classes and mappings of `Char`, and what the library's PreludeRuntime names
beside the Report's (`runtime-library`: arrays, an IOError's details, the
IO family's positions of files and errors of the system's). `end-*.core`
hold the line an escaping IOError ends a program with to the library's Show
IOError, a user's "user error (TEXT)". `lib/language/haskell/coreruntime`
(`tests/lib/language/haskell/coreruntime.sml`) holds the runtime's tables to
`lib/unicode`'s `CodePoint` at every code point below 0x100, every 1999th,
and the first and the last of each range and run of its data.

E1's eight programs, rewritten in Core (`knot`, `cafs`, `monad`, `classes`,
`nest`, `nest2`, `letpoly`, `exceptions`), print E1's hand-derived output,
`knot`'s count of evaluations of a shared suspension among it. Each rule of
CoreLint has its fault, `lint-RULE.core`, refused with its message, which
`hs/core/@rules` holds to `bin/rhc --lint-rules` in both directions. A
loop, an error no handler takes, a stack deeper than `--depth` and the
steps of `--steps` run out are one bottom: rhc says which on standard error
and ends with status 1 (`bottom-*.core`). `hs/core/@generated` runs 32
programs of Core's generator (`bin/rhc --generate-core=SEED`; the roadmap's
D55), each of which must pass CoreLint at level 3 and run to a value or to
the bottom the generator puts in its input, and `hs/core/@silent` holds the
judge of a run to failing a silent one.

Each run test is also compiled by rhc through Mid (the roadmap's M10: `bin/rhc
-o FILE`) at `-O0` and `-O2` to the register bytecode and run on its VM
interpreted and at tier 2 (`hs/core/vm/NAME`, `check`), and at `-O1` there and
at each level to the stack bytecode on the stack VM (`hs/core/vm-rest/NAME`,
nightly): it
prints what Core's interpreter printed and ends as it did, every bottom one
bottom, a status other than 0. E1's programs, each with a line `; ways: E1`,
also run nightly in E1's forty-five ways, twelve modes of the register VM and
three of the stack VM at each level (`hs/core/vm45/NAME`; the roadmap's D56
puts three ways of a run in `make check` and the rest nightly), and
`hs/core/@generated` compiles each of its programs too, which must print on
the VM what the interpreter printed and end in a bottom where it did. A test whose answer is the interpreter's alone
says why on a line `; vm: no: REASON`, and is the interpreter's only: one
whose answer depends on a suspension that raised being forced again, which
the interpreter puts back and form C leaves under evaluation (the roadmap's
D12; Haskell 98 cannot tell, since its `catch` takes `IOError` alone), one on
a bound only the interpreter has, `--steps` or `--depth`, and one that waits
on a milestone. A line `; residency: SIZE1 SIZE2` compiles the program with
each of two files of `tests/hs/core/lib` that define `size`, and holds the
most live with a collection at every allocation (`runevm --stats`) to the
same at both, at `-O0` and `-O2`, interpreted and at tier 2
(`hs/core/residency/NAME`: E2's `last` and `leak`, D12); a line `; budget:
SIZE1 SIZE2` holds what `--count` counts at the second to at most 2.2 times
the first (`hs/core/budget/NAME`), a sharing budget, rhc's policy and not the
Report's, which a lost share, growing exponentially, breaks (D6).

## rhc in units

rhc's separate compilation (the haskell98 roadmap's M21) has its tests under
`tests/hs/units`, run by the family `hs/units/*` (`tests/runner/hsunits.sml`;
tier `test-rhc`, part of `make check`). `hs/units/store` compiles
`tests/hs/units/store.sml` with Pickle, `UnitStore` and rhc's `RhcStore` and
nothing of a compiler, as `tests/lib/compiler/store.sml` tests Rune's store,
and runs it: an entry is found by its key and stands by its usages judged
against what is given now, an absent name present now refuses it (H1, H2);
one checked at a lower level of the lint is refused; a key is over every
member and its text (H8); the overlay is read before the layers, a layer is
read and never written, one configuration's entries are not another's; a
damaged entry is a miss; a head is read back as it was written. Core in
units has its tests among `hs/core`'s, `tests/hs/core/units-*.core`: a unit
that takes a value of another by an import (`(import x TYPE)`) and a type by
a copy of its declaration, the units joined (`CoreUnits.join`) and run; an
import no unit defines, a type two units declare apart and an import at
another type than its definition's, each refused; an import printed and
read back, in a unit checked alone (`--typecheck-only`).

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
test program, but for a compile in units by `smlnj32`, whose hash is its
own (`building.md`, *Bootstrapping*). This rests on the compiler
being deterministic: ordered maps, counter-generated stamps, reals passed
through as text.

`reproducible/counts` also repeats a small whole compile and a compile in
units without a cache, with a cold cache, and with a warm cache. Within
each case, bytecode and VM instruction/allocation counts must agree.
Sources, options, environment, and initial filesystem state are held
fixed: in particular the output exists before each run, so the checks
against overwriting an input perform the same work. Different cache
states and filesystem errors need different work and are separate cases.
Normal stages do not sample clocks or accumulate timing totals;
`--pass-stats` explicitly requests that measurement. Temporary names are
reserved by the OS and never enter emitted bytecode or cache keys.

For controlled variation, `bin/rune-test compiler-stress --seed 1 --runs 16`
uses a fixed pseudo-random sequence to vary the VM's nursery size and JIT
thresholds while it runs the compiler on the same source. Every eighth
case also verifies the heap. Each result must match the ordinary run's
bytecode and VM instruction/allocation counts. The commands and errors
are kept under the test output directory in `compiler-stress-SEED` for
replay with `sh case-N.command`; each command restores the working
directory, output-file state, and the runner's lint and arithmetic-backend
settings. Other inherited environment settings must remain the same.
The seed changes testing conditions only; normal compilation
does not choose random settings.

The example inventory covers top-level sources and sources one directory
below `examples`. `tests/runner/exampleprojects.sml` distinguishes standalone
programs from `.build` applications and their shared fragments. Example job
and artifact names include their directory, so root `hello.sml` and SDL's
`hello.sml` cannot collide. Unknown build entrypoints or unclassified project
members fail the inventory audit.

`check-cross` and `check-positions` compile the Win32 mock application through
`examples/win32/mock.build`, and `lib/ffi/win32/mock/contract` compiles the
shared Win32 contract against the mock and runs it, which needs no SDL. The
generated providers have focused compilation
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

### Mutants of the compiler

`make test-compiler-mutants` (tier `test-compiler-mutants`,
`tests/runner/compilermutants.sml`) takes about an hour and a quarter at eight
jobs, 7.6 hours of CPU, so it runs as a job of its own in the nightly
workflow and not in `make check`. It asks which check
catches which bug seeded in the compiler (plans/correctness/linting.md, E3
and M4). Each of its 68 mutants (`tests/runner/compilermutantlist.sml`) is
one or more exact edits of the compiler's sources -- a type substitution
dropped, a representation swapped, a fix reverted -- built with
`bin/rune.rbc` into a compiler of its own. It compiles a fixed corpus as
`bin/rune.rbc` did, at level 0: `tests/lang` and `tests/perf` at `-O0` and
`-O2`, 24 tests of the Basis, a sample of `tests/lang` on the stack target
and in units (`--units`, and `--units --whole -O2`), `tests/errors` for the
mutants of the elaborator and Translate, a dynamic module and the program
that loads it (`tests/compiler/mutants`), a functor of an earlier unit
inlined (`tests/units/functor-earlier`), a functor's function kept in its
unit (`mod.functor.functions_capture`, in units), and the bootstrap. An
item whose bytes differ exercises the mutant; up to 160 of those are
compiled again at level 2 and run in each of their ways against
`bin/rune.rbc`'s runs (run twice; an unstable run gives no verdict). Where
no byte differs, a quarter of that sample of the corpus and its extra items
are compiled at level 2 still, for a mutant only a lint sees. Each mutant's job says what saw
it -- `LINT` (which lint, after which stage), `OTHER` (the compiler
stopping, a program of `tests/errors` accepted, the VM's loader or checks,
the output, `-O0` against `-O2`, the bootstrap's stage two), `UNCAUGHT`,
or `UNEXERCISED` -- and the summary, with how many of the 27 a lint caught in
E3 one still catches, is in `tests/out/compiler-mutants`.
A controller that breaks is a FAIL, never a verdict; the good compiler's
lint refusing an item it compiles is one too, and so are a mutant that no
longer compiles, which seeds nothing, and a mutant of `lintCaught`, the 54 a
lint catches, that a lint no longer does (add one a lint comes to catch). `COMPILER_MUTANTS=E01,M02`
runs those mutants alone, and `COMPILER_MUTANTS_QUICK=N` keeps the first N
items of each part of the corpus, to try the harness.

`make check` holds the mutants to the sources between those runs, as they
went stale unseen when nothing did: `compiler-mutants/prepare` applies every
mutant's edits, and `compiler-mutants/built-ID` builds each one, about 7
minutes of CPU in all. It says nothing of what catches them.

### The checks of the cache

A hit claims that compiling the unit again would give the entry
([units.md](units.md), *Checking it*, and `tests/incremental/model.sml`). That
rests on a key covering what a compile reads, and the compiler's reads, spread
through every pass and table, and the key, kept by hand, are two pieces of code
that nothing ties together but tests. A scenario says what its author thought
of; when anyone looked, real holes appeared (build-system roadmap, E18). So each
premise has a check of its own, independent of the scenarios, in `make
test-incremental` and so in `make check`, as a scenario of
`bin/rune-incremental`:

| Check | What fails it | Where |
|---|---|---|
| The flags oracle, `flag-*` | an option or a `RUNE_` variable of the compiler's sources with no row saying whether it reaches a key; a row's claim not holding, each way: through a cache filled without the setting, a build with it against the same build without a cache, and the other way about, in exit status, bytes and text; and each setting of the language once more on a library's file (`flag-lib-*`): the library's unit compiled again where the setting reaches it (`--or-patterns`, `--no-unicode-lints` and the configuration's), and taken where it does not (`--default-type`, `--unicode`, `--allow-prim`, the input files') | `tests/runner/cacheflags.sml` |
| Fact edits, `fact-*` | an edit that flips one fact a fingerprint or the configuration holds, the value's name and type kept, compiling other units than the row says, or differing from a build without the cache | `tests/runner/cachefacts.sml` |
| Root blanking, `blank-*` | a root of `CompilerState` that changes what a compile makes when it goes back to its baseline, and that `tests/incremental/roots.tsv` does not say what covers | `tests/runner/cachechecks.sml`, `src/driver/cachecheck.sml` |
| Verification of all hits, `across-*`, S98 | `--verify-cache` finding that an entry taken across a unit that changed is not what compiling the unit gives | the same |
| Random edits, `@mutate`, `@mutate-verify` | a warm build that disagrees with `--no-cache`, or that `--verify-cache` refuses; a build that fails whose plan `--verify-cache` refuses. Among the edits, a fixity directive changed, added, removed, made `nonfix` or put in a `local` that keeps it or drops it, so that the files after it parse another way, or not at all (`tests/incremental/fixity`) | `tests/runner/mutationchecks.sml`, `tests/runner/mutationproject.sml` |
| The model, `model` | the model of a hit saying otherwise than `tests/incremental/model.expected` | `tests/incremental/model.sml` |
| The fingerprint oracle, `fp-oracle` | a field of a binding, or a fact of the tables a fingerprint reads by hand, changed alone, moving a fingerprint in other layers than the description of the codecs marks it in (`tools/codecs/compiler.sml`), or a sameness not saying what the description has it compare; or a kind of field or fact the program does not change | `tests/runner/cachechecks.sml`, `UnitBasis.fpOracle` ([units.md](units.md), *The fingerprint oracle*) |
| Unit by unit, and the mask, `warm-unit-*` | a unit compiled alone, while every other is taken from the cache without its basis, that is not what its entry holds: under its view, what its text names loaded by need, or under the mask of its entry's usages, each structure cut to the paths they name and only the units their binders reach loaded | `tests/runner/warmchecks.sml` |
| The racy cases, `warm-racy`; up to date, `warm-uptodate`, `warm-uptodate-index` | a warm build that differs from one without the cache after an edit the stat memo or a memo could miss: of the same size within the second of a build, the old text back with its old times, an edit with its time put back, the output overwritten or removed, a new name, a `library.build` above a unit, a Basis Library file edited under an index of the frozen layer or of the overlay | the same |
| The plan, `warm-plan`, S131 | a build that reads, lexes and parses other files for its plan than the edit and the fixity it moved say ([units.md](units.md), *A warm build*): the file edited; after a fixity directive changed, added, removed, made `nonfix` or put in a `local` that drops it, the files after it; after one put in a `local` that keeps it, that file alone. A warm build that differs from one without the cache, where a file's text is the same and the fixity before it is not; `--verify-cache` finding what the store keeps of a file is not what reading it gives | `tests/runner/warmchecks.sml`, `tests/runner/incrementalextra.sml` |
| Two roots, one store, `warm-index-roots`, `warm-plan-roots` | two copies of the Basis Library under two `--lib` roots, built in turn through one store, not keeping a record of each one's index there, or a build from one writing again the record of the other's; in units, the same of each root's plan | the same |
| Where the store is, `store-place` | a build, a build of another first line, a build run from below the root, a file given by itself or the REPL's `use` keeping a store anywhere but beside the workspace's `rune.workspace`, or two builds of one workspace not sharing it; `RUNE_CACHE` or `--cache-dir` not moving it; with no workspace, none beside the build file | `tests/runner/storechecks.sml` |
| Trimming, `store-trim` | a build after the store was trimmed -- to sizes from the whole down to a byte, by age by hand and after a build, every other file and every third removed -- that differs from one without the store; a build after a build that trimmed compiling what that build took; a trim of the frozen layer, or a limit that is none, not refused | the same |
| Damage, `store-damage` | an entry damaged where it still reads, its hashes kept -- in its head so that it stands, or in its first section -- taken rather than compiled; a damaged Mid read by a build of the units' code, or taken by `--whole` | the same |
| Stale entries, `store-heads` | a lookup through a store with stale entries under a project's keys hashing more of the store than one through a store of its entries alone | the same |

The roots come from `CompilerState.names`, not a list: a new root needs no line
until a compile reads it. Blanking cannot see a flag left at its default, which
is what the oracle is for, and the oracle cannot see state no option sets, which
is what blanking is for. `blank-*` takes three small groups, twelve units, each
child a fork and a small compile. By hand, `RUNE_BLANK_ROOTS=FILE` makes any
compile with `--no-cache` do it, of the input files or of the units
`RUNE_BLANK_UNITS=A,B` names.

`--verify-cache` compiles each unit it finds. An entry whose usages hold by
binder must be the same bytes. One that holds by fingerprint names the old
unit, so what is compared is the same thing made from each side: the entry
loaded with its names remapped as a build would, and the unit compiled, each
with its basis written again from what loading it left, without what only a
hash reads, and its code read and written, a unit's identity left out. It
compares an entry's basis and code, not its Mid, and an entry that does not load
in a session that compiled the units before it is what a build would miss, and
says so under `--explain-rebuild`. Build-cache issue 15 closed with M4's step 2
of the build-system roadmap, since a basis written again is the same bytes.

They are 99 tests of `make test-incremental`: 500 s of CPU, of which the
flags oracle's 66 are 167 s (2026-11-03). `make test-cache-random`
is the random edits at length, 150 steps of each small project with every warm
build verified and 12 of the compiler's own sources, in the nightly tier; a
change to a key runs it. `RUNE_CACHE_SEED=N` draws other edits.

A unit compiled under the mask, `RUNE_VERIFY_UNIT=NAME` with `RUNE_VERIFY_MASK`
set (NAME its file or its logical name), sees only what its entry's usages
name, and the tables by stamp only what the units their binders reach put
there: it sees a read of a table the usages do not name, which no root
blanking can, since every root is at its value. Without `RUNE_VERIFY_MASK` the
unit sees its view, what its text names (units.md, *A warm build*), as a build
on the warm path does; with `--explain-rebuild` either says how many units it
loaded. What the mask leaves: the units a used unit's basis names, whose
tables are all there, used or not.

What these do not do. The fingerprint oracle changes what the description
marks, and a fact of the tables it knows of: a fact a fingerprint should read
and nobody wrote down is what the fact edits and the mask are for. A type is
changed as a whole or in its first type variable's equality, not part by
part. `rune-repl`'s own options are not in the flags oracle's rows, and a
pass of these on small projects says that they ran there, nothing more.

**The mutants of the cache** (`tests/runner/cachemutantlist.sml`, E18's and those
added for each check) are built as the compiler's are, and run in
`make test-compiler-mutants`, or alone by `make test-cache-mutants`. A compile
of a corpus sees none of them, so each names the checks that must fail on it and
what they must say, and the tier fails where one does not;
`compiler-mutants/cache-control` runs those checks with no mutant, which must
pass. `make check` holds them to the sources through `compiler-mutants/prepare`.
A1 to A6 are a virtual or dynamic functor's ABI (the build-system roadmap's
M21): A1 to A4 make it another -- its version, its calling convention, the
records' slots in another order, the descriptors in another -- and a module
of the mutant is refused by a client of `bin/rune` when it loads it (S128 of
`tests/incremental/SCENARIOS.md`); A5 and A6 take a signature out of the
fingerprint, and a module of another signature with the same slots is then
taken (S129, S130). C5 and C14 are the store's
(the build-system roadmap's M7): an entry's sections, or its head, not held to
their hashes, so that an entry damaged where it still reads is taken, which
`store-damage` sees. P1 keeps what a file is to the plan by its text alone, as
E15's plan memo did, not by the fixity before it: S131 sees the program take
the Basis Library's file a parse that failed before named, and `warm-plan` a
fixity edit read one file where it should read those after it; random edits
of `tests/incremental/fixity` with `--verify` see it too, 9 builds of 50.
The 13 that survived E18:

| Mutant | What it drops | Issue | What became of it |
|---|---|---:|---|
| F1 | `valFacts`: `Translate.primAliases` | | Harmless to a compile: a value bound to a primitive is a function that applies it, so `Expand.primGlobals`, which the fingerprint also hashes, says the same. `F14` drops both, and `fact-primfunction` and `fact-primdirect` catch it; since M5, `fp-oracle`, which changes the fact alone |
| F4 | `valFacts`: `Expand.primGlobals` | | `fact-primfunction`: the client reaches the function by a structure's other name, so that its usage is the structure, and no `inlv` says what the function is |
| F5 | `fpAnchored`: which value, the anchor | 8 | `fact-anchor`: a structure's other name made to reach another value of the type, which a remap by the old path would find wrongly |
| F6 | `fpConinfo`: a constructor's tag | | Harmless to a compile: a constructor's scheme names its type, and the definition holds the constructors in order, which is what a tag is; since M5, `fp-oracle`, which changes the tag alone |
| F9 | a definition: a type name's equality | 16 | `fact-eqname`: an abstract type, whose definition is nothing else |
| U3 | the usage `fun` | | Harmless since the build-system roadmap's M4: an application calls the functor's function, whose global no path reaches, so where the functor's unit changed an entry that calls it is not remapped and its unit is compiled (`its entry names ... a name no path of it reaches`), and where it did not nothing changed. `across-project` saw it only while an entry exact by its binders that named a changed unit failed to load; such an entry is taken across now |
| U4 | the usage `inl` | | `fact-inlfunctor`: E18's scenarios had no marked functor outside the Basis |
| K1 | the key's `allow` | | `flag-allow-prim`: filled with the flag, built without it |
| K5 | the configuration's `inline-val` | | `fact-markvalue`: the mark taken out of a build file |
| C1 | a unit still in the session is a bar to a fingerprint | 21, 23 | S75 on the mutant's REPL, which the tier builds: in a batch build two units of one name do not arise |
| C3 | `absent`, the units an entry's code names | 4 | S99: an entry planted in a program that takes nothing across a change, the one place nothing else refuses it |
| C6 | a unit that keeps identities takes none across a change | 15 | S61, on the reason: with the guard gone `absent` refuses the entry, and the build is the same |
| C9 | a signature's usage fingerprinted after the unit | 17 | S100: an unrelated edit compiles the unit that declares the name again |
| M2 | `UnitMid`: the layouts a body fixed | | S101: only with the application left a call, where the layout decides the bytes |

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
install or dist. Three cases of deps are the build-system roadmap's E8 table
([units.md](units.md), *Well-formed units*): `wellformed-rune` holds every
library and build of the tree to `rune --deps --build` finding no unit that
is not well-formed, `wellformed-hol4` holds HOL4's 744 units of the
`src/boss` closure so, and `wellformed-mlton` MLton's 606 but for 13, below.
`RUNE_WELLFORMED_MLTON`
names a copy of MLton's sources (`mlton`, `lib/mlton`, `lib/mlyacc-lib`,
`lib/stubs`, from `MLTON_SOURCES`, symbolic links followed) with flat build
files laid over it, which a translator from MLton's `.mlb` files,
`impl/bs-m14/mlb2build3.py` of the build-system roadmap's drafts, makes: 30
build files, one for each `.mlb` of its closure and two for the Makefile's
lists of stubs, `mlton/mlton.build` the program, each `.mlb` it includes a
plain `use`, and MLB's `local` flattened, with no library. The row runs on
that flat build: its 606 units, of which 13 are not well-formed, each
declaring a name another unit declares too, 17 names in all, which MLB's
`local` keeps apart (`STREAM` and `Stream` of `lib/mlton` and
`lib/mlyacc-lib`, `CONTROL`, `FIELD` and `Field`, `MLton`, and the `xml/` and
x86 copies of `ssa/` and amd64 passes). The row expects exactly those, by unit
and by name, and fails on one more or one fewer. M9's library form of MLton,
which had all 606 well-formed, cannot be written under D9: its libraries
export 16 names of the Basis Library and 5 names come from two or three of
them, which a library with a header may not ([build.md](build.md),
*Clashes*), so a codebase that shadows the Basis renames before it can have
headers. `RUNE_WELLFORMED_HOL4`
names a directory of the closure after HOL's filter with its `boss.build`,
which declares its two preludes; `rune --deps` then finishes on the closure as
a plain list. Without them those two say SKIP. Installation also accepts repeated `--host NAME`; Make's
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
