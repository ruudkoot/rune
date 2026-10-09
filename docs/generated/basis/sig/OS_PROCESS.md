# signature OS_PROCESS

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **OS_PROCESS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | 39 checks of 10 entries |
| Source | [lib/basis/sig\_os\_process.sml](../../../../lib/basis/sig_os_process.sml) |

## Synopsis

```sml
signature OS_PROCESS
structure OS.Process : OS_PROCESS
```

| Implementation |  | Source |
| --- | --- | --- |
| [`OS.Process`](../str/OS.Process.md) | OS.Process: the status a program ends with, running a command, the environment, and ending the program. | [lib/basis/os.sml](../../../../lib/basis/os.sml) |

The process itself: its environment, the commands it runs, and how it
ends.

[`exit`](#val-exit) ends the program the orderly way: the actions given to [`atExit`](#val-atexit) are
run, the streams are flushed, and only then does the process stop.
[`terminate`](#val-terminate) stops it at once, without any of that.

## Interface

<pre>
signature OS_PROCESS =
sig
  type <a href="#type-status">status</a>
  val <a href="#val-success">success</a> : status
  val <a href="#val-failure">failure</a> : status
  val <a href="#val-issuccess">isSuccess</a> : status -&gt; bool
  val <a href="#val-system">system</a> : string -&gt; status
  val <a href="#val-atexit">atExit</a> : (unit -&gt; unit) -&gt; unit
  val <a href="#val-exit">exit</a> : status -&gt; 'a
  val <a href="#val-terminate">terminate</a> : status -&gt; 'a
  val <a href="#val-getenv">getEnv</a> : string -&gt; string option
  val <a href="#val-sleep">sleep</a> : Time.time -&gt; unit
end
</pre>

### <a name="type-status"></a>`status`

```sml
type status
```

The type of what a program ends with, and what a command it ran ended with.

> **Implementation** `OS.Process.status/of-a-command`. The status of a
> command that [`system`](#val-system) ran is its exit code, or 256 plus the number of
> the signal that ended it, which [`Posix.Process.fromStatus`](../sig/POSIX_PROCESS.md#val-fromstatus) decodes.

<details><summary>Tests (1)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `list-of-statuses`

</details>

### <a name="val-success"></a>`success`

```sml
val success : status
```

The status of a program that did what it was meant to do; there is only one.

<details><summary>Tests (1)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `isSuccess`

</details>

### <a name="val-failure"></a>`failure`

```sml
val failure : status
```

A status of a program that did not; there are others.

**Example** `isSuccess failure = false`

<details><summary>Tests (1)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `not-isSuccess`

</details>

### <a name="val-issuccess"></a>`isSuccess`

```sml
val isSuccess : status -> bool
```

`isSuccess st` is `true` when `st` is a status of a program that succeeded.

> **Reading** `OS.Process.isSuccess/killed-is-not-success`. A command that a
> signal ended has not succeeded: from [`UNIX`](../sig/UNIX.md), this is true only where
> [`Posix.Process.fromStatus`](../sig/POSIX_PROCESS.md#val-fromstatus) gives `W_EXITED`.

**Example** `isSuccess success = true`

<details><summary>Tests (2)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `twice` &middot; `killed-by-signal`

</details>

### <a name="val-system"></a>`system`

```sml
val system : string -> status
```

`system cmd` runs `cmd` and is the status it ended with.

A command that the shell cannot find ends with the shell's status 127,
which is no success.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the command could not be run at all.

> **Reading** `OS.Process.system/a-real-shell`. A shell runs the command, so
> redirection, sequencing and variables work; it runs in the current
> directory, and [`system`](#val-system) returns only once the command is done. What the
> process has buffered is neither lost nor written twice by running one.

**Example** `isSuccess (system "true") = true`

**Example** `isSuccess (system "exit 3") = false`

<details><summary>Tests (15)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `exit-0` &middot; `exit-3` &middot; `exit-1` &middot; `exit-255` &middot; `true` &middot; `false` &middot; `empty-command` &middot; `unknown-command` &middot; `shell-redirection` &middot; `current-directory` &middot; `shell-syntax` &middot; `status-of-last-command` &middot; `status-of-and-list` &middot; `waits-for-the-command` &middot; `keeps-buffered-output`

</details>

### <a name="val-atexit"></a>`atExit`

```sml
val atExit : (unit -> unit) -> unit
```

`atExit f` asks for `f` to be run when the program ends.

> **Implementation** `OS.Process.atExit/how-actions-run`. The actions run in
> the reverse of the order they were given in, at a normal end and at
> [`exit`](#val-exit) but not at [`terminate`](#val-terminate) and not after an uncaught exception. The
> exception of an action that raises is dropped and the others run, and
> an action that calls [`atExit`](#val-atexit) registers nothing.

<details><summary>Tests (3)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `not-run-at-registration` &middot; `action-that-raises` &middot; `action-that-registers`

</details>

### <a name="val-exit"></a>`exit`

```sml
val exit : status -> 'a
```

`exit st` ends the program with the status `st`, after running the [`atExit`](#val-atexit) actions and flushing the streams.

> **Reading** `OS.Process.exit/what-is-flushed`. "Flushes and closes all I/O
> streams" reaches the streams the library still holds output for, over
> writers a program supplied; output to a file is held by the VM, which
> flushes every file itself.

> **Implementation** `OS.Process.exit/status-of-a-command`. The status of a
> command that [`system`](#val-system) ran keeps its exit code, and one of a command that
> a signal ended, which no exit code can express, ends the program as
> [`failure`](#val-failure) does, as the specification's implementation note asks.

<details><summary>Other implementations (3)</summary>

- **MLKit** &mdash; the status that OS.Process.system gives is success or failure (\~1) and nothing else, so exit ends the child with 255 whatever the command ended with (docs/bugreport/mlkit/Unix.reap/status-lost)
- **MLton** &mdash; exit of the status of a command raises (the exit code must be below 256), where the specification's implementation note asks that the command's exit code be passed on, and failure for a command that a signal ended (docs/bugreport/mlton/OS.Process.status/two-representations)
- **Poly/ML** &mdash; a child that calls exit with the status of a command has not ended after 5 seconds, when the check kills it (docs/bugreport/polyml/OS.Process.exit/status-of-system)

</details>

<details><summary>Tests (4)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `result-has-any-type` &middot; `result-has-any-type-string`

For `OS.Process`, in [tests/basis/unix.sml](../../../../tests/basis/unix.sml): `keeps-the-exit-code-of-a-command` &middot; `signal-status-is-failure`

</details>

### <a name="val-terminate"></a>`terminate`

```sml
val terminate : status -> 'a
```

`terminate st` ends the program with the status `st` at once.

No [`atExit`](#val-atexit) action runs and nothing the library holds is flushed.

<details><summary>Tests (2)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `result-has-any-type` &middot; `result-has-any-type-string`

</details>

### <a name="val-getenv"></a>`getEnv`

```sml
val getEnv : string -> string option
```

`getEnv name` is `SOME` of the value of the environment variable `name`, or `NONE`.

> **Reading** `OS.Process.getEnv/the-whole-name`. The whole name must match:
> a name that merely begins with one that is set does not, and neither
> does a name with `"=value"` attached. A command run by [`system`](#val-system) inherits
> this environment and cannot change it.

**Example** `getEnv "A_VARIABLE_THAT_NOBODY_SETS" = NONE`

<details><summary>Tests (7)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `unset` &middot; `PATH-is-set` &middot; `stable` &middot; `name-that-extends-a-set-name` &middot; `name-with-value-attached` &middot; `agrees-with-the-shell` &middot; `not-set-by-a-command`

</details>

### <a name="val-sleep"></a>`sleep`

```sml
val sleep : Time.time -> unit
```

`sleep t` waits for the time `t`, and returns at once when `t` is not positive.

Nothing is raised, whatever `t` is.

**Example** `(sleep (Time.fromReal ~1.0); "returned") = "returned"`

<details><summary>Tests (3)</summary>

For `OS.Process`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `zero` &middot; `positive` &middot; `positive-not-much-longer`

</details>

## See also

[`OS`](../sig/OS.md), [`UNIX`](../sig/UNIX.md), [`POSIX_PROCESS`](../sig/POSIX_PROCESS.md), [`TIME`](../sig/TIME.md)

---

<sub>Generated by runedoc from lib/basis/sig\_os\_process.sml; do not edit.</sub>
