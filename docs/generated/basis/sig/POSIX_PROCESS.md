# signature POSIX_PROCESS

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **POSIX_PROCESS**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 22 of 22 entries documented |
| Tests | 50 checks of 16 entries |
| Source | [lib/basis/sig\_posix\_process.sml](../../../../lib/basis/sig_posix_process.sml) |

## Synopsis

```sml
signature POSIX_PROCESS
structure Posix.Process : POSIX_PROCESS  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.Process` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

Processes: making them, replacing them, waiting for them and ending them.

[`fork`](#val-fork) splits the process in two and is the only way a POSIX program makes
another; the [`exec`](#val-exec) family replaces the program that a process is running,
and never returns. The two together are how a program runs another: fork,
then exec in the child, then [`waitpid`](#val-waitpid) in the parent. [`UNIX`](../sig/UNIX.md) wraps that up
for the common case.

A child that has ended is remembered until it is waited for, and [`wait`](#val-wait)
and [`waitpid`](#val-waitpid) report how it ended as an [`exit_status`](#type-exit_status).

> **Erratum** `POSIX_PROCESS/flexible-types`. The types [`signal`](#type-signal) and
> [`pid`](#type-pid) are left flexible here, as on the page; [`POSIX`](../sig/POSIX.md) fixes [`signal`](#type-signal) to
> [`Posix.Signal.signal`](../sig/POSIX_SIGNAL.md#type-signal), and the identities stated only in the text are checked in
> the suite rather than written into the signature.

## Interface

<pre>
signature POSIX_PROCESS =
sig
  eqtype <a href="#type-signal">signal</a>

  eqtype <a href="#type-pid">pid</a>

  val <a href="#val-wordtopid">wordToPid</a> : SysWord.word -&gt; pid

  val <a href="#val-pidtoword">pidToWord</a> : pid -&gt; SysWord.word

  val <a href="#val-fork">fork</a> : unit -&gt; pid option

  val <a href="#val-exec">exec</a> : string * string list -&gt; 'a

  val <a href="#val-exece">exece</a> : string * string list * string list -&gt; 'a

  val <a href="#val-execp">execp</a> : string * string list -&gt; 'a

  datatype <a href="#type-waitpid_arg">waitpid_arg</a>
    = <a href="#con-w_any_child">W_ANY_CHILD</a>
    | <a href="#con-w_child">W_CHILD</a> of pid
    | <a href="#con-w_same_group">W_SAME_GROUP</a>
    | <a href="#con-w_group">W_GROUP</a> of pid

  datatype <a href="#type-exit_status">exit_status</a>
    = <a href="#con-w_exited">W_EXITED</a>
    | <a href="#con-w_exitstatus">W_EXITSTATUS</a> of Word8.word
    | <a href="#con-w_signaled">W_SIGNALED</a> of signal
    | <a href="#con-w_stopped">W_STOPPED</a> of signal

  val <a href="#val-fromstatus">fromStatus</a> : OS.Process.status -&gt; exit_status

  structure <a href="#str-w">W</a> :
  sig
    include BIT_FLAGS

    val <a href="#val-w.untraced">untraced</a> : flags
  end

  val <a href="#val-wait">wait</a> : unit -&gt; pid * exit_status

  val <a href="#val-waitpid">waitpid</a> : waitpid_arg * W.flags list -&gt; pid * exit_status

  val <a href="#val-waitpid_nh">waitpid_nh</a> : waitpid_arg * W.flags list -&gt; (pid * exit_status) option

  val <a href="#val-exit">exit</a> : Word8.word -&gt; 'a

  datatype <a href="#type-killpid_arg">killpid_arg</a>
    = <a href="#con-k_proc">K_PROC</a> of pid
    | <a href="#con-k_same_group">K_SAME_GROUP</a>
    | <a href="#con-k_group">K_GROUP</a> of pid

  val <a href="#val-kill">kill</a> : killpid_arg * signal -&gt; unit

  val <a href="#val-alarm">alarm</a> : Time.time -&gt; Time.time

  val <a href="#val-pause">pause</a> : unit -&gt; unit

  val <a href="#val-sleep">sleep</a> : Time.time -&gt; Time.time
end
</pre>

### <a name="type-signal"></a>`signal`

```sml
eqtype signal
```

The type of a signal, the one of [`Posix.Signal`](../sig/POSIX.md#str-signal).

### <a name="type-pid"></a>`pid`

```sml
eqtype pid
```

The type of the number that names a process.

### <a name="val-wordtopid"></a>`wordToPid`

```sml
val wordToPid : SysWord.word -> pid
```

`wordToPid w` is the process whose number is `w`.

<details><summary>Tests (1)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `no-validation`

</details>

### <a name="val-pidtoword"></a>`pidToWord`

```sml
val pidToWord : pid -> SysWord.word
```

`pidToWord pid` is the number of `pid`.

<details><summary>Tests (2)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `wordToPid` &middot; `positive`

</details>

### <a name="val-fork"></a>`fork`

```sml
val fork : unit -> pid option
```

`fork ()` splits the process in two, and is `NONE` in the child and `SOME` of the child's number in the parent.

The child has a copy of everything the parent had: its memory, its open
descriptors and its current directory.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no process can be made.

> **Implementation** `Posix.Process.fork/a-second-vm-where-there-is-none`.
> Windows has no [`fork`](#val-fork). There the VM starts a second one of itself and
> hands it this one's whole state -- the heap, the stacks, the program,
> the open files, the sockets and the directory streams -- and the child
> carries on from the [`fork`](#val-fork) as a copy of the process would. That costs
> about 12 milliseconds, and 3 more for each megabyte of live data, where
> a [`fork`](#val-fork) the kernel makes costs almost nothing.

> **Limitation** `Posix.Process.fork/read-ahead-of-a-pipe`. Where the [`fork`](#val-fork)
> is that second VM, what the C library has read ahead from a pipe or a
> terminal, and the program has not taken yet, stays with the parent
> alone: an input that can seek is put back to where the program had
> read, and a pipe cannot be. A [`fork`](#val-fork) the kernel makes gives the child a
> copy of it.

<details><summary>Tests (4)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `pid-of-child` &middot; `parent-keeps-pid` &middot; `child-is-a-copy` &middot; `child-changes-are-its-own`

</details>

### <a name="val-exec"></a>`exec`

```sml
val exec : string * string list -> 'a
```

`exec (path, args)` replaces the running program by the one at `path`, and does not return.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the program cannot be run.

> **Reading** `Posix.Process.exec/args-and-path`. The first item of `args` is
> the new program's argument zero and is passed as it stands, not replaced
> by `path`. And `path` is a pathname: a name with no slash in it is not
> looked for along `PATH`, which is what [`execp`](#val-execp) is for.

<details><summary>Tests (7)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `status` &middot; `args` &middot; `argument-0` &middot; `same-process` &middot; `same-environment` &middot; `not-searched` &middot; `missing-file-raises`

</details>

### <a name="val-exece"></a>`exece`

```sml
val exece : string * string list * string list -> 'a
```

`exece (path, args, env)` is [`exec`](#val-exec) with `env` as the new program's environment.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the program cannot be run.

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `environment` &middot; `empty-environment` &middot; `missing-file-raises`

</details>

### <a name="val-execp"></a>`execp`

```sml
val execp : string * string list -> 'a
```

`execp (file, args)` is [`exec`](#val-exec) with `file` looked for along `PATH` when it holds no slash.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the program cannot be found or run.

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `searched` &middot; `with-slash` &middot; `missing-raises`

</details>

### <a name="type-waitpid_arg"></a>`waitpid_arg`

```sml
datatype waitpid_arg
  = W_ANY_CHILD
  | W_CHILD of pid
  | W_SAME_GROUP
  | W_GROUP of pid
```

Which child [`waitpid`](#val-waitpid) is to wait for.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-w_any_child"></a>`W_ANY_CHILD` |  | any child of this process |
| <a name="con-w_child"></a>`W_CHILD` | `pid` | that one child |
| <a name="con-w_same_group"></a>`W_SAME_GROUP` |  | any child in this process's group |
| <a name="con-w_group"></a>`W_GROUP` | `pid` | any child in that group |

### <a name="type-exit_status"></a>`exit_status`

```sml
datatype exit_status
  = W_EXITED
  | W_EXITSTATUS of Word8.word
  | W_SIGNALED of signal
  | W_STOPPED of signal
```

How a process ended, or why it stopped.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-w_exited"></a>`W_EXITED` |  | it ended of itself, successfully |
| <a name="con-w_exitstatus"></a>`W_EXITSTATUS` | `Word8.word` | it ended of itself, with that status |
| <a name="con-w_signaled"></a>`W_SIGNALED` | `signal` | a signal ended it |
| <a name="con-w_stopped"></a>`W_STOPPED` | `signal` | a signal stopped it; it has not ended |

### <a name="val-fromstatus"></a>`fromStatus`

```sml
val fromStatus : OS.Process.status -> exit_status
```

`fromStatus st` is what the status `st` says about how the process ended.

> **Implementation** `Posix.Process.fromStatus/status-encoding`. An
> [`OS.Process.status`](../sig/OS_PROCESS.md#type-status) is an `int`: the exit code of a process that ended of
> itself, 256 and the number of the signal that ended it, or 512 and the
> number of the signal that stopped it.

<details><summary>Other implementations (2)</summary>

- **MLton, Poly/ML** &mdash; fromStatus OS.Process.failure is W\_SIGNALED, not W\_EXITSTATUS of a non-zero value
- **SML/NJ** &mdash; OS.Process.system returns failure (W\_EXITSTATUS 1) for a command that a signal ended

</details>

<details><summary>Tests (6)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `success` &middot; `failure` &middot; `system-exit-0` &middot; `system-exit-3` &middot; `system-exit-200` &middot; `system-killed`

</details>

### <a name="str-w"></a>`W`

The flags that say what [`waitpid`](#val-waitpid) is to wait for.

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype | The type of a set of flags. |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val | `toWord fl` is the word whose bits are the flags of `fl`. |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val | `fromWord w` is the set of the flags that the bits of `w` name. |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val | Every flag the system uses here. |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val | `flags l` is the union of the sets of `l`: a flag is in it when it is in one of them. |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val | `intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them. |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val | `clear (fl, gl)` is `gl` without the flags of `fl`. |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val | `allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`. |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val | `anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`. |

#### <a name="val-w.untraced"></a>`untraced`

```sml
val untraced : flags
```

Report a child that has stopped as well as one that has ended.

> **Reading** `Posix.Process.W.untraced/needed-for-stopped`. Without it a
> child that is merely stopped does not end the wait: [`waitpid_nh`](#val-waitpid_nh)
> gives `NONE`.

> **Implementation** `Posix.Process.W/only-untraced`. It is the only flag
> here; the `WNOHANG` of POSIX is what [`waitpid_nh`](#val-waitpid_nh) is, and is added by
> that function itself.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; W.allSet (fl1, fl2) tests whether fl2 is in fl1: the arguments are swapped

</details>

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `in-all` &middot; `nonempty` &middot; `waitpid-without-it`

</details>

### <a name="val-wait"></a>`wait`

```sml
val wait : unit -> pid * exit_status
```

`wait ()` waits for any child to end and is its number and how it ended.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the process has no child.

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `child` &middot; `already-ended` &middot; `no-child` (raises)

</details>

### <a name="val-waitpid"></a>`waitpid`

```sml
val waitpid : waitpid_arg * W.flags list -> pid * exit_status
```

`waitpid (arg, flags)` waits for the child that `arg` names and is its number and how it ended.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such child.

<details><summary>Tests (1)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `no-child` (raises)

</details>

### <a name="val-waitpid_nh"></a>`waitpid_nh`

```sml
val waitpid_nh : waitpid_arg * W.flags list -> (pid * exit_status) option
```

`waitpid_nh (arg, flags)` is [`waitpid`](#val-waitpid) that does not wait: `NONE` when no such child has ended yet.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such child at all.

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `running-child` &middot; `ended-child` &middot; `no-child` (raises)

</details>

### <a name="val-exit"></a>`exit`

```sml
val exit : Word8.word -> 'a
```

`exit st` ends the process at once with the status `st`.

Nothing is flushed and no [`OS.Process.atExit`](../sig/OS_PROCESS.md#val-atexit) action runs; it is the
`_exit` of POSIX.

<details><summary>Other implementations (1)</summary>

- **Poly/ML 5.9.2** &mdash; a forked child that calls Posix.Process.exit (or OS.Process.exit) never ends

</details>

<details><summary>Tests (5)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `status` &middot; `zero` &middot; `no-atExit` &middot; `no-flush` &middot; `result-has-any-type`

</details>

### <a name="type-killpid_arg"></a>`killpid_arg`

```sml
datatype killpid_arg
  = K_PROC of pid
  | K_SAME_GROUP
  | K_GROUP of pid
```

Which process [`kill`](#val-kill) is to signal.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-k_proc"></a>`K_PROC` | `pid` | that one process |
| <a name="con-k_same_group"></a>`K_SAME_GROUP` |  | every process in this one's group |
| <a name="con-k_group"></a>`K_GROUP` | `pid` | every process in that group |

### <a name="val-kill"></a>`kill`

```sml
val kill : killpid_arg * signal -> unit
```

`kill (arg, s)` sends the signal `s` to the process or the group that `arg` names.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such process, or the signal may not
be sent to it.

<details><summary>Tests (2)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `term` &middot; `no-such-process` (raises)

</details>

### <a name="val-alarm"></a>`alarm`

```sml
val alarm : Time.time -> Time.time
```

`alarm t` asks for [`Posix.Signal.alrm`](../sig/POSIX_SIGNAL.md#val-alrm) in `t`, and is the time left of the alarm that was set before.

> **Reading** `Posix.Process.alarm/zero-cancels`. A time of zero asks for no
> alarm, as POSIX has it, so it cancels the outstanding one and still
> reports the time that was left of it.

<details><summary>Tests (3)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `none-outstanding` &middot; `remaining` &middot; `cancelled`

</details>

### <a name="val-pause"></a>`pause`

```sml
val pause : unit -> unit
```

`pause ()` waits until a signal arrives.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; a forked child that pauses is not ended by the signal (alrm, usr1) that ends the same pause in the main process

</details>

<details><summary>Tests (2)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `until-alarm` &middot; `until-signal`

</details>

### <a name="val-sleep"></a>`sleep`

```sml
val sleep : Time.time -> Time.time
```

`sleep t` waits for the time `t` and is the time left of it.

> **Reading** `Posix.Process.sleep/time-left`. The page does not say what the
> result is; it is POSIX's "time left", which is zero when the wait ran
> out and the rest when a signal cut it short.

<details><summary>Tests (2)</summary>

For `Posix.Process`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `one-second` &middot; `zero`

</details>

## See also

[`POSIX`](../sig/POSIX.md), [`UNIX`](../sig/UNIX.md), [`POSIX_SIGNAL`](../sig/POSIX_SIGNAL.md), [`OS_PROCESS`](../sig/OS_PROCESS.md)

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_process.sml; do not edit.</sub>
