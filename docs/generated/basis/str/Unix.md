# structure Unix

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Unix**

|  |  |
| --- | --- |
| Signature | [`UNIX`](../sig/UNIX.md) |
| Status | optional |
| Members | 14 |
| Tests | 36 checks |
| Source | [lib/basis/unix.sml](../../../../lib/basis/unix.sml) |

## Synopsis

```sml
structure Unix : UNIX where type exit_status = Posix.Process.exit_status where type signal = Posix.Signal.signal
```

Unix: running a program and talking to it through pipes.

## Members

What each means is on [`UNIX`](../sig/UNIX.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| datatype | [`exit_status`](../sig/UNIX.md#type-exit_status) | `W_EXITED` &#124; `W_EXITSTATUS` &#124; `W_SIGNALED` &#124; `W_STOPPED` |
| type | [`proc`](../sig/UNIX.md#type-proc) | *a type of its own* |
| type | [`signal`](../sig/UNIX.md#type-signal) | `RunePosixSignal.signal` |
| val | [`binInstreamOf`](../sig/UNIX.md#val-bininstreamof) | `(BinIO.instream, 'a) proc -> BinIO.instream` |
| val | [`binOutstreamOf`](../sig/UNIX.md#val-binoutstreamof) | `('a, BinIO.outstream) proc -> BinIO.outstream` |
| val | [`execute`](../sig/UNIX.md#val-execute) | `string * string list -> ('a, 'b) proc` |
| val | [`executeInEnv`](../sig/UNIX.md#val-executeinenv) | `string * string list * string list -> ('a, 'b) proc` |
| val | [`exit`](../sig/UNIX.md#val-exit) | `Word8.word -> 'a` |
| val | [`fromStatus`](../sig/UNIX.md#val-fromstatus) | `RuneStatus.status -> RunePosixProcess.exit_status` |
| val | [`kill`](../sig/UNIX.md#val-kill) | `('a, 'b) proc * RunePosixSignal.signal -> unit` |
| val | [`reap`](../sig/UNIX.md#val-reap) | `('a, 'b) proc -> RuneStatus.status` |
| val | [`streamsOf`](../sig/UNIX.md#val-streamsof) | `(TextIO.instream, TextIO.outstream) proc -> TextIO.instream * TextIO.outstream` |
| val | [`textInstreamOf`](../sig/UNIX.md#val-textinstreamof) | `(TextIO.instream, 'a) proc -> TextIO.instream` |
| val | [`textOutstreamOf`](../sig/UNIX.md#val-textoutstreamof) | `('a, TextIO.outstream) proc -> TextIO.outstream` |

## Notes

### execute

> **Reading** `Unix.execute/current-directory`. The page does not say which
> directory the child runs in; it is this process's current one.

### executeInEnv

> **Implementation** `Unix.executeInEnv/exec-failure-is-126`. A child whose
> `exec` fails ends with the status 126, as the page asks; that is what a
> [`reap`](../sig/UNIX.md#val-reap) of it reports, rather than an exception in the parent. On
> Windows, which starts a program without a child of this one's and
> knows at once that it cannot be run, this raises [`OS.SysErr`](../sig/OS.md#exn-syserr), which
> the page allows as well.

### exit

> **Reading** `Unix.exit/flushes`. It runs the [`OS.Process.atExit`](../sig/OS_PROCESS.md#val-atexit) actions
> and then leaves through the VM's exit, which flushes every file; that is
> taken to satisfy "flushes and closes all I/O streams".

### reap

> **Reading** `Unix.reap/status-is-remembered`. The status is kept, so
> reaping the same process again gives the same answer rather than
> failing. A child that is merely stopped does not end the wait, since
> [`Posix.Process.W.untraced`](../sig/POSIX_PROCESS.md#val-w.untraced) is not asked for.

<details><summary>Other implementations (14)</summary>

- **MLton** &mdash; Unix.fromStatus misreads the statuses that reap returns (exit 3 is W\_SIGNALED; a process that term ended is W\_SIGNALED of signal 1)
- **MLKit** &mdash; the status of a process that did not succeed is W\_EXITSTATUS 0w255 whatever its exit status or signal: reap reduces every failure to OS.Process.failure (an int, \~1), which fromStatus maps to W\_EXITSTATUS 0wxFF
- **MLton** &mdash; Unix.fromStatus misreads the statuses that reap returns (exit 5 is W\_SIGNALED)
- **SML/NJ** &mdash; a child that cannot execute the command exits with 1 (after reporting an uncaught SysErr), not 126
- **MLKit** &mdash; a child that cannot execute the command does not exit with 126: the SysErr of exece propagates out of Unix.execute in the child, which goes on running the caller's program
- **MLKit** &mdash; exece (and so Unix.executeInEnv) with the environment \[\] passes on the environment of the process: the runtime installs the list only when it is not empty
- **SML/NJ** &mdash; Unix.exit does not flush the output streams that are open
- **Poly/ML 5.9.2** &mdash; a forked child that calls Unix.exit never ends
- **SML/NJ** &mdash; Unix.exit does not run the actions of OS.Process.atExit
- **MLKit** &mdash; Unix.exit is Posix.Process.exit: it neither runs the actions of OS.Process.atExit nor flushes the output streams
- **MLton, Poly/ML** &mdash; fromStatus OS.Process.failure is W\_SIGNALED, not W\_EXITSTATUS of a non-zero value
- **MLKit** &mdash; the status of a process that did not succeed is W\_EXITSTATUS 0w255 whatever its exit status or signal: OS.Process.system and Unix.reap reduce every failure to OS.Process.failure (an int, \~1), which fromStatus maps to W\_EXITSTATUS 0wxFF
- **MLton** &mdash; Unix.fromStatus misreads the statuses that reap returns (a process that term or kill ended is W\_SIGNALED of signal 1)
- **MLKit** &mdash; the status of a process that a signal ended is W\_EXITSTATUS 0w255, not W\_SIGNALED: reap reduces every failure to OS.Process.failure (an int, \~1), which fromStatus maps to W\_EXITSTATUS 0wxFF

</details>

---

<sub>Generated by runedoc from lib/basis/unix.sml; do not edit.</sub>
