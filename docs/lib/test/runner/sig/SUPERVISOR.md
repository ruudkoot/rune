# signature SUPERVISOR

[Running tests](../README.md) &rsaquo; Running tests &rsaquo; **SUPERVISOR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 6 of 6 entries documented |
| Tests | not listed |
| Source | [lib/test/runner/supervisor\_sig.sml](../../../../../lib/test/runner/supervisor_sig.sml) |

## Synopsis

```sml
signature SUPERVISOR
structure Supervisor :> SUPERVISOR
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Supervisor`](../str/Supervisor.md) | The supervisor: children in groups, reaped with what they cost, ended for their time or their output, and the scheduler's admission. | [lib/test/runner/supervisor.sml](../../../../../lib/test/runner/supervisor.sml) |

Running jobs as children (docs/plans/unit-testing.md, D9 and D11): one
loop that starts what the scheduler admits, reaps what ended, ends what
ran too long or wrote too much, and sleeps a little when nothing
happened. There are no threads and no handlers of signals but the
interrupt, so this loop is the runner.

A job is a process in a process group of its own (a job on Windows), with
its standard input from a file and its output and errors to files, which
a crash leaves on disk; its signals start at their default actions. A
job that runs past its time is sent TERM, and KILL after a grace period;
one whose output passes its cap is stopped by its file-size limit and by
the loop, which looks at the files' sizes. When the job's process has
ended and its group has not, the rest of the group is killed and the job
is said to have left processes behind.

## Interface

<pre>
signature SUPERVISOR =
sig
  type <a href="#type-command">command</a> = {<a href="#fld-command.program">program</a> : string, <a href="#fld-command.args">args</a> : string list, <a href="#fld-command.env">env</a> : string list, <a href="#fld-command.dir">dir</a> : string,
                  <a href="#fld-command.stdin">stdin</a> : string, <a href="#fld-command.stdout">stdout</a> : string, <a href="#fld-command.stderr">stderr</a> : string, <a href="#fld-command.timeout">timeout</a> : Time.time, <a href="#fld-command.cap">cap</a> : int,
                  <a href="#fld-command.cost">cost</a> : real, <a href="#fld-command.cpus">cpus</a> : int, <a href="#fld-command.memory">memory</a> : int, <a href="#fld-command.pools">pools</a> : string list, <a href="#fld-command.exclusive">exclusive</a> : bool,
                  <a href="#fld-command.failedlast">failedLast</a> : bool, <a href="#fld-command.deps">deps</a> : int list}
  datatype <a href="#type-outcome">outcome</a> = <a href="#con-exited">Exited</a> of int | <a href="#con-signalled">Signalled</a> of int | <a href="#con-timedout">TimedOut</a> | <a href="#con-capped">Capped</a> | <a href="#con-cancelled">Cancelled</a> | <a href="#con-failed">Failed</a> of string
  datatype <a href="#type-verdict">verdict</a> = <a href="#con-passed">Passed</a> | <a href="#con-notpassed">NotPassed</a> | <a href="#con-again">Again</a>
  type <a href="#type-result">result</a> = {<a href="#fld-result.outcome">outcome</a> : outcome, <a href="#fld-result.wall">wall</a> : Time.time, <a href="#fld-result.user">user</a> : Time.time, <a href="#fld-result.system">system</a> : Time.time,
                 <a href="#fld-result.peakresident">peakResident</a> : int, <a href="#fld-result.outputbytes">outputBytes</a> : int, <a href="#fld-result.leaked">leaked</a> : bool}
  val <a href="#val-outcomename">outcomeName</a> : outcome -&gt; string
  val <a href="#val-run">run</a> : {<a href="#fld-run.commands">commands</a> : command vector, <a href="#fld-run.cpus">cpus</a> : int, <a href="#fld-run.memory">memory</a> : int,
             <a href="#fld-run.finished">finished</a> : int * result -&gt; verdict, <a href="#fld-run.tick">tick</a> : int -&gt; unit} -&gt; unit
end
</pre>

### <a name="type-command"></a>`command`

```sml
type command = {program : string, args : string list, env : string list, dir : string,
                stdin : string, stdout : string, stderr : string, timeout : Time.time, cap : int,
                cost : real, cpus : int, memory : int, pools : string list, exclusive : bool,
                failedLast : bool, deps : int list}
```

A command to run: the program and its arguments, its environment and
directory, the files of its streams, its time and cap, and what it takes.

The arguments begin with the program's name. `cap` limits the bytes of
its output and errors, and of any file it writes (0 for none). The
rest is what the scheduler needs ([`Scheduler.job`](../sig/SCHEDULER.md#type-job)).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-command.program"></a>`program` | `string` |  |
| <a name="fld-command.args"></a>`args` | `string list` |  |
| <a name="fld-command.env"></a>`env` | `string list` |  |
| <a name="fld-command.dir"></a>`dir` | `string` |  |
| <a name="fld-command.stdin"></a>`stdin` | `string` |  |
| <a name="fld-command.stdout"></a>`stdout` | `string` |  |
| <a name="fld-command.stderr"></a>`stderr` | `string` |  |
| <a name="fld-command.timeout"></a>`timeout` | `Time.time` |  |
| <a name="fld-command.cap"></a>`cap` | `int` |  |
| <a name="fld-command.cost"></a>`cost` | `real` |  |
| <a name="fld-command.cpus"></a>`cpus` | `int` |  |
| <a name="fld-command.memory"></a>`memory` | `int` |  |
| <a name="fld-command.pools"></a>`pools` | `string list` |  |
| <a name="fld-command.exclusive"></a>`exclusive` | `bool` |  |
| <a name="fld-command.failedlast"></a>`failedLast` | `bool` |  |
| <a name="fld-command.deps"></a>`deps` | `int list` |  |

### <a name="type-outcome"></a>`outcome`

```sml
datatype outcome = Exited of int | Signalled of int | TimedOut | Capped | Cancelled | Failed of string
```

How a command ended: its exit status or signal, ended by the loop, or
never started.

The loop ends a command for its time ([`TimedOut`](#con-timedout)) or its output
([`Capped`](#con-capped)). A command is [`Cancelled`](#con-cancelled) when a job it waited for did not
end well, and [`Failed`](#con-failed) when the system refused to start it.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-exited"></a>`Exited` | `int` |  |
| <a name="con-signalled"></a>`Signalled` | `int` |  |
| <a name="con-timedout"></a>`TimedOut` |  |  |
| <a name="con-capped"></a>`Capped` |  |  |
| <a name="con-cancelled"></a>`Cancelled` |  |  |
| <a name="con-failed"></a>`Failed` | `string` |  |

### <a name="type-verdict"></a>`verdict`

```sml
datatype verdict = Passed | NotPassed | Again
```

What a command came to: it passed, it did not, or it is to run again
(a test that may be flaky, the first time it fails).

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-passed"></a>`Passed` |  |  |
| <a name="con-notpassed"></a>`NotPassed` |  |  |
| <a name="con-again"></a>`Again` |  |  |

### <a name="type-result"></a>`result`

```sml
type result = {outcome : outcome, wall : Time.time, user : Time.time, system : Time.time,
               peakResident : int, outputBytes : int, leaked : bool}
```

What a command cost: its times, its memory and its output, and whether
it left processes behind.

The wall time is on the monotonic clock; `peakResident` is the most
memory it held resident, in kilobytes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-result.outcome"></a>`outcome` | `outcome` |  |
| <a name="fld-result.wall"></a>`wall` | `Time.time` |  |
| <a name="fld-result.user"></a>`user` | `Time.time` |  |
| <a name="fld-result.system"></a>`system` | `Time.time` |  |
| <a name="fld-result.peakresident"></a>`peakResident` | `int` |  |
| <a name="fld-result.outputbytes"></a>`outputBytes` | `int` |  |
| <a name="fld-result.leaked"></a>`leaked` | `bool` |  |

### <a name="val-outcomename"></a>`outcomeName`

```sml
val outcomeName : outcome -> string
```

`outcomeName oc` is `oc` as a word or two, for a report.

**Example** `outcomeName (Exited 3) = "exit 3"`

### <a name="val-run"></a>`run`

```sml
val run : {commands : command vector, cpus : int, memory : int,
           finished : int * result -> verdict, tick : int -> unit} -> unit
```

`run {commands, cpus, memory, finished, tick}` runs `commands` as
[`Scheduler.admit`](../sig/SCHEDULER.md#val-admit) admits them, and tells `finished` each one's result.

The machine has `cpus` processors and `memory` megabytes. `tick` is
called with the number running whenever the loop has nothing to do,
for a display.

`finished` says what the command came to; one to run [`Again`](#con-again) is
started again. A command that waits for one that did not pass is not
started, and is [`Cancelled`](#con-cancelled). An interrupt ([`SML90.Interrupt`](../../../basis/sig/SML90.md#exn-interrupt)) kills every
running group and is raised again.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-run.commands"></a>`commands` | `command vector` |  |
| <a name="fld-run.cpus"></a>`cpus` | `int` |  |
| <a name="fld-run.memory"></a>`memory` | `int` |  |
| <a name="fld-run.finished"></a>`finished` | `int * result -> verdict` |  |
| <a name="fld-run.tick"></a>`tick` | `int -> unit` |  |

---

<sub>Generated by runedoc from lib/test/runner/supervisor\_sig.sml; do not edit.</sub>
