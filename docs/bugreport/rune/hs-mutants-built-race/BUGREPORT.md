# rhc's mutants: a mutant's job and its built job share a directory, and one removes the other's

Found 2026-11-14, in the lead's `make test-rhc-mutants`, where four of rhc's
mutants ended in an uncaught `OS.SysErr` that the trace put in
`RuneStreamIOFn.flushOut`. Status: fixed 2026-11-14 on `hs-l`
(`015bfa058`, `d6a6d9e08`). The trace's wrong place is a bug of its own, not fixed:
[handler-reraise-position](../handler-reraise-position/BUGREPORT.md).

## What happened

The lead started the tier in the worktree `h98-chk-g2nightly3`, at haskell98
`f006fe359` (M21), from a tool shell that then ran `sleep 30` and exited,
about 10:16:15 (UTC), without `nohup` or `setsid`:

```
( exec 9>lock; flock -x 9; ... make test-rhc-mutants ... ) > /dev/null 2>&1 &
```

Run `20261114-101556-4166989` (`tests/out/r/` of that tree):

```
RESULT: FAIL 79 of 79 tests (74 PASS, 4 FAIL, 1 SKIP), 431.5 s wall, 2556.6 s CPU (99% of 6)
```

| Job | Verdict | Wall |
|---|---|---:|
| `hs-mutants/HU07` | FAIL, exit 1 | 34.8 s |
| `hs-mutants/HU08` | FAIL, exit 1 | 13.4 s |
| `hs-mutants/HU09` | FAIL, exit 1 | 13.0 s |
| `hs-mutants/HU11` | FAIL, exit 1 | 19.2 s |
| `hs-mutants/final` | SKIP: it waits for them | |

Each of the four wrote nothing to its standard output, and this to its
standard error:

```
runevm: uncaught exception SysErr <value>
  in RuneStreamIOFn.flushOut at bin/../lib/basis/streamio_fn.sml:333:104
  in <toplevel> at tests/runner/main.sml:232:60
```

None of the four left a verdict in `hs-mutants/verdicts`. There was no
`hs-mutants/HU07` to `HU11` directory, where `HU01` to `HU06` have theirs.
In `h98-chk-g2nightly3` the lead ran the four again and they passed, 11 of 11
(run `20261114-105521-46453`).

## Not reproduced at first

L's runs, at haskell98 `80792e82d` in `h98-l` (the logs are in
`~/.cache/claude-rune-drafts/haskell98/impl/l/`):

| Run | What | Result |
|---|---|---|
| `20261114-102838-4192355` | `bin/rune-test run -j 1 --tier test-rhc-mutants hs-mutants/HU07` | 8 of 8 PASS |
| `20261114-103054-308` | the four by path, `-j 4`, `GC_STRESS=101 NATIVE_HOST=yes` | 11 of 11 PASS |
| `20261114-103555-4998` | the whole tier, `-j 6`, as `make test-rhc-mutants` runs it | 79 of 79 PASS |
| `20261114-105017-38226` | the four, with `bin/rune-test` built from `f006fe359`'s `tests/runner` | 11 of 11 PASS |

A flush of the standard output that fails raises `IO.Io`, not `SysErr`:
`bin/rune-test hs-mutant HU10 > /dev/full` ends with `uncaught exception Io
<value>` and the same two frames. A program's standard output closed or
full gives `Io` too, on the register VM, under `--jit=all`, at -O2 at tier
2, and on the stack VM. `guarded` (`lib/basis/streamio_fn.sml`) wraps the
writer's `SysErr` as the cause of the `Io`.

The runs of the four by path, the lead's included, have no built jobs, and
in the whole tier it is a matter of timing (below).

## The hypothesis: the tool shell's exit

The lead's hypothesis: when the shell exited, a `SIGHUP` to its process
group, or its pipes closing, hit the jobs then running. Tested with HU07
alone through the runner, at `80792e82d`, the scripts `sig.sh` and `pipe.sh`
in `~/.cache/claude-rune-drafts/haskell98/impl/l/sigtest/`:

| What | Run | HU07 |
|---|---|---|
| `SIGHUP` to the job's process group, 10 s into the job | `20261114-110735-67018` | CRASH, "ended by signal 1"; nothing on its stdout or stderr |
| `SIGINT`, the same | `20261114-110850-68979` | CRASH, "ended by signal 2"; nothing |
| `SIGTERM`, the same | `20261114-111009-73167` | CRASH, "ended by signal 15"; nothing |
| the runner's output to a pipe whose reader goes 100 s in, as HU07 runs | `20261114-112217-88515` | the runner ends at its next line of progress (`SIGPIPE`), with no summary; HU07 runs on and says CAUGHT in its own files |
| the same, the reader gone 1 s before HU07 ends | `20261114-111249-77126` | PASS; the runner ends at its summary |
| the runner's stdout and stderr closed | `20261114-111558-80894` | PASS; the runner exits 1, with no summary |
| as the lead started it: `> /dev/null 2>&1 &`, from a shell gone 10 s in | `20261114-111915-84673` | PASS, 8 of 8; the runner exits 0 |

None prints the `SysErr`, and none could have hit the lead's jobs:

- **The jobs have their own process groups.** `Supervisor.start`
  (`lib/test/runner/supervisor.sml`) spawns each with `group = true`, so a
  signal to the shell's group does not reach them. In `sig.sh`, each job's
  group was its own pid.
- **There was no pipe.** The run's output went to `/dev/null`.
- **The runner was not hit.** It wrote its summary.
- **The timing does not fit.** The four ran from about 10:22:30 to 10:23:17,
  six minutes after the shell ended (below).

## The cause

Each mutant ID has two jobs in the tier: ID, which builds it, compares its
outputs and runs the jobs it names, and built-ID, which builds it and
removes what it built. Both build with `CompilerMutants.buildFrom` into
`dirOf id`, `RUN/hs-mutants/ID`. Both write `RUN/hs-mutants/ID.sources`.
`buildFrom` begins with `rmTree d; mkdirs (d ^ "/src")`, and `builtJob` ends
with `rmTree (dirOf id)`. Nothing orders the two jobs: built-ID waits for
`prepare`, ID for `good`.

The scheduler puts the jobs in order of their chains (`Scheduler.plan`, by
cost and what waits, ties by number). good → ID → final is the long chain,
and nothing waits for built-ID, so the built jobs run in the slots that
good leaves free. A built job left over when good ends waits until no ID job
is waiting, and then runs beside the last ID jobs. When built-ID runs while
ID is running, it removes ID's directory (its `rhc.rbc`, `scratch`, the
mutant's tree). ID then fails at its next operation in that directory with
`OS.SysErr` (`ENOENT`). `HsMutants.protect` caught only `Failed`, so the
exception ended the job, and its trace named `flushOut`
([handler-reraise-position](../handler-reraise-position/BUGREPORT.md)).

In the lead's run, 25 built jobs ended before good (55.5 s), and 5 just after
it. The last five, built-HU07 to built-HU11, ran at the end. The times of
the `.sources` files say when each build began. The order of the events is
the order in which the jobs ended:

| Time (UTC) | What |
|---|---|
| 10:21:16 to 10:22:20 | HU01 to HU06 begin |
| about 10:22:31 | HU07 begins (its end less its wall), about 5 s after HU01 ends |
| about 10:22:54 to 10:22:58 | HU08, HU09, HU10 and HU11 begin, each about 5 s after one of HU02 to HU05 ends |
| 10:23:06.46 | HU10 (EQUIVALENT, 10.4 s) has ended; built-HU07 begins in its slot, and HU07 ends |
| 10:23:06.86, 07.27, 07.71 | built-HU08, built-HU09 and built-HU10 begin, each in the slot of the job before it; HU08 and HU09 end |
| 10:23:17.15 | built-HU07 has ended (10.7 s); built-HU11 begins, and HU11 ends |
| 10:23:27.9 | built-HU11 ends |
| 10:23:35.4 | HU06 ends, the last job |

The events, in that order: HU10 PASS, HU07 FAIL, final SKIP, HU08 FAIL,
HU09 FAIL, built-HU07 PASS, HU11 FAIL, built-HU08 to built-HU11 PASS,
HU06 PASS. Each of the four ended as its built job began, and its slot went
to the next built job. HU06 lived because built-HU06 had run during good,
and HU10 because it had ended. Each built job's last `rmTree` explains the
missing HU07 to HU11 directories.

Whether a built job is left over depends on how fast the built jobs run
during good, so on the machine's load. That is why the runs above passed.

## Reproduced

`race.sh` (beside this file) runs `hs-mutant HU07` and, DELAY seconds in,
`hs-mutant-built HU07`, in one run directory, as the tier did. With a
watch of `RUN/hs-mutants/HU07` every 0.5 s, at DELAY 30
(`~/.cache/claude-rune-drafts/haskell98/impl/l/sigtest/race2.sh`):

| `bin/rune-test` | HU07's mutant job | Its built job |
|---|---|---|
| `80792e82d`'s | ends 31.7 s in, exit 1, with the lead's three lines of stderr exactly | PASS, 40.5 s in |
| with `protect` catching every exception | ends 32.5 s in: `FAIL hs-mutants: SysErr: No such file or directory (noent)` | PASS, 43.7 s in |
| with both fixes | CAUGHT, 86.4 s in | PASS, 46.4 s in |

The watch: the mutant's build ended at about 10 s (`rhc.rbc` and `scratch`
there). At about 32 s the directory held only the built job's `build.err` and
`src`, and the mutant ended. It was comparing outputs then, and each output
is a file in `scratch` that `Children.exec` creates (`Posix.FileSys.creat`).

## The fix

On `hs-l`, in `tests/runner/hsmutants.sml`:

- **Separate directories.** `build (m, dir)` builds in `dirOf dir`: ID's job
  in `ID`, built-ID's in `built-ID`, with its own `built-ID.sources`
  (`d6a6d9e08`).
- **`protect` catches every exception.** It says any exception, not only
  `Failed`, in a `FAIL hs-mutants:` line, by `Sh.exnText`. A job that a
  harness exception stops then has a FAIL verdict with its cause, not an
  uncaught exception with a misleading trace (`015bfa058`).

Checked: `race.sh` with both: the mutant CAUGHT, the built job PASS. And
`make test-rhc-mutants` at `-j 6`: 79 of 79 PASS, `final` too, 35 CAUGHT and 1
EQUIVALENT (run `20261114-113722-109622`).

## Not this bug, but alike

Rune's own compiler mutants (`tests/runner/compilermutants.sml`) have the
same layout: `compiler-mutants/built-ID` and `compiler-mutants/ID` both
build in `compiler-mutants/ID`. There built-ID is in `make check` and ID in
`make test-compiler-mutants`, so the two meet only in a run that selects
both. Not changed.
