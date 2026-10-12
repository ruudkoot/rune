# signature RUN

[Running tests](../README.md) &rsaquo; Running tests &rsaquo; **RUN**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 7 of 7 entries documented |
| Tests | not listed |
| Source | [lib/test/runner/run\_sig.sml](../../../../../lib/test/runner/run_sig.sml) |

## Synopsis

```sml
signature RUN
structure Run :> RUN
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Run`](../str/Run.md) | A run of commands: directories, the environment, verdicts, retention and the history. | [lib/test/runner/run.sml](../../../../../lib/test/runner/run.sml) |

A run of tests that are commands (docs/plans/unit-testing.md, M3): each
in a directory of its own of a fixed width under the run's directory, or
in a directory it names; judged when it ends; its directory removed when
it passed and kept when it did not; its wall time recorded in the
history; and every outcome reported.

## Interface

<pre>
signature RUN =
sig
  type <a href="#type-command">command</a> = {<a href="#fld-command.program">program</a> : string, <a href="#fld-command.args">args</a> : string list, <a href="#fld-command.env">env</a> : string list option, <a href="#fld-command.dir">dir</a> : string option,
                  <a href="#fld-command.stdin">stdin</a> : string option, <a href="#fld-command.timeout">timeout</a> : Time.time, <a href="#fld-command.cap">cap</a> : int, <a href="#fld-command.cpus">cpus</a> : int, <a href="#fld-command.memory">memory</a> : int,
                  <a href="#fld-command.pools">pools</a> : string list, <a href="#fld-command.exclusive">exclusive</a> : bool, <a href="#fld-command.after">after</a> : string list,
                  <a href="#fld-command.judge">judge</a> : Supervisor.result * {stdout : string, stderr : string} -&gt; (string * string) option}
  val <a href="#val-exitzero">exitZero</a> : Supervisor.result * {<a href="#fld-exitzero.stdout">stdout</a> : string, <a href="#fld-exitzero.stderr">stderr</a> : string} -&gt; (string * string) option
  val <a href="#val-shell">shell</a> : string * int -&gt; command
  val <a href="#val-index">index</a> : string vector -&gt; string -&gt; int option
  val <a href="#val-tail">tail</a> : int * string -&gt; string
  val <a href="#val-accept">accept</a> : bool ref
  val <a href="#val-run">run</a> : {<a href="#fld-run.tests">tests</a> : (string * Test.meta * command) list, <a href="#fld-run.root">root</a> : string, <a href="#fld-run.out">out</a> : string, <a href="#fld-run.history">history</a> : string,
             <a href="#fld-run.cpus">cpus</a> : int, <a href="#fld-run.memory">memory</a> : int, <a href="#fld-run.keep">keep</a> : bool, <a href="#fld-run.reader">reader</a> : Report.reader,
             <a href="#fld-run.capabilities">capabilities</a> : Requirements.capability list, <a href="#fld-run.strict">strict</a> : bool, <a href="#fld-run.quarantine">quarantine</a> : Expectations.line list} -&gt; bool
end
</pre>

### <a name="type-command"></a>`command`

```sml
type command = {program : string, args : string list, env : string list option, dir : string option,
                stdin : string option, timeout : Time.time, cap : int, cpus : int, memory : int,
                pools : string list, exclusive : bool, after : string list,
                judge : Supervisor.result * {stdout : string, stderr : string} -> (string * string) option}
```

A test that is a command: what runs, where, what it may take, what it
waits for, and how its verdict is found.

`after` names the tests it waits for by path. `judge` finds the
verdict from how the command ended and the files of its output and
errors: `NONE` passes, and `SOME (verdict, reason)` does not. `dir` is
`NONE` for a directory of its own. `env` is `NONE` for the runner's
environment without what would make a `make` inside it a part of the
runner's own (`MAKELEVEL`, `MFLAGS`, and the jobs and jobserver of
`MAKEFLAGS`, whose variables stay) or force colour (`FORCE_COLOR`,
`CLICOLOR_FORCE`). A command takes no more CPUs than the run has, and
finds how many it has in `RUNE_TEST_CPUS`, the run's directory in
`RUNE_TEST_RUN` and the tree's in `RUNE_TEST_ROOT`, both absolute;
`RUNE_TEST_ACCEPT` is 1 in a run that accepts ([`accept`](#val-accept)).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-command.program"></a>`program` | `string` |  |
| <a name="fld-command.args"></a>`args` | `string list` |  |
| <a name="fld-command.env"></a>`env` | `string list option` |  |
| <a name="fld-command.dir"></a>`dir` | `string option` |  |
| <a name="fld-command.stdin"></a>`stdin` | `string option` |  |
| <a name="fld-command.timeout"></a>`timeout` | `Time.time` |  |
| <a name="fld-command.cap"></a>`cap` | `int` |  |
| <a name="fld-command.cpus"></a>`cpus` | `int` |  |
| <a name="fld-command.memory"></a>`memory` | `int` |  |
| <a name="fld-command.pools"></a>`pools` | `string list` |  |
| <a name="fld-command.exclusive"></a>`exclusive` | `bool` |  |
| <a name="fld-command.after"></a>`after` | `string list` |  |
| <a name="fld-command.judge"></a>`judge` | `Supervisor.result * {stdout : string, stderr : string} -> (string * string) option` |  |

### <a name="val-exitzero"></a>`exitZero`

```sml
val exitZero : Supervisor.result * {stdout : string, stderr : string} -> (string * string) option
```

`exitZero (r, files)` is the verdict of a command that passes when it
exits with 0.

Otherwise its verdict is `FAIL`, `TIMEOUT`, `CRASH` (a signal) or
`LEAK` (it left processes behind), with the end of its output.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-exitzero.stdout"></a>`stdout` | `string` |  |
| <a name="fld-exitzero.stderr"></a>`stderr` | `string` |  |

### <a name="val-shell"></a>`shell`

```sml
val shell : string * int -> command
```

`shell (script, cpus)` is a command that runs `script` with `/bin/sh -c`
in the directory of the tree, judged by [`exitZero`](#val-exitzero).

Its timeout is an hour, and its output has no cap.

### <a name="val-index"></a>`index`

```sml
val index : string vector -> string -> int option
```

`index names` finds a name among `names`: its place, or `NONE`.

**Example** `index (Vector.fromList ["b", "a"]) "a" = SOME 1`

### <a name="val-tail"></a>`tail`

```sml
val tail : int * string -> string
```

`tail (n, file)` is the last `n` lines of `file`, or "" when there is
none.

### <a name="val-accept"></a>`accept`

```sml
val accept : bool ref
```

Whether the run accepts what its tests printed as what they should
print (`--accept`).

A judge that reads a golden file writes it instead, and says
`ACCEPTED`. It is `false` unless the command line sets it.

### <a name="val-run"></a>`run`

```sml
val run : {tests : (string * Test.meta * command) list, root : string, out : string, history : string,
           cpus : int, memory : int, keep : bool, reader : Report.reader,
           capabilities : Requirements.capability list, strict : bool, quarantine : Expectations.line list} -> bool
```

`run {tests, root, out, history, cpus, memory, keep, reader, capabilities, strict, quarantine}` runs `tests` under `out`, and is
whether every test passed.

Each run has a new directory under `out`.

The tree's directory is `root`; the run has `cpus` processors and
`memory` megabytes; it reads and rewrites the history file `history`;
and `keep` keeps every test's directory. A test that requires a
capability the machine lacks (of `capabilities`) does not run: it is
skipped with the capability's hint, or is an ERROR when `strict`, and
the tests that wait for it do not start.

A test tagged `flaky` that fails runs once more, and is `FLAKY` (no
failure) when it passes then. A failure that a line of `quarantine`
covers, of the way `rune-test` and the test's path, is `QUARANTINED`
until the line's date, and a failure again after it.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-run.tests"></a>`tests` | `(string * Test.meta * command) list` |  |
| <a name="fld-run.root"></a>`root` | `string` |  |
| <a name="fld-run.out"></a>`out` | `string` |  |
| <a name="fld-run.history"></a>`history` | `string` |  |
| <a name="fld-run.cpus"></a>`cpus` | `int` |  |
| <a name="fld-run.memory"></a>`memory` | `int` |  |
| <a name="fld-run.keep"></a>`keep` | `bool` |  |
| <a name="fld-run.reader"></a>`reader` | `Report.reader` |  |
| <a name="fld-run.capabilities"></a>`capabilities` | `Requirements.capability list` |  |
| <a name="fld-run.strict"></a>`strict` | `bool` |  |
| <a name="fld-run.quarantine"></a>`quarantine` | `Expectations.line list` |  |

---

<sub>Generated by runedoc from lib/test/runner/run\_sig.sml; do not edit.</sub>
