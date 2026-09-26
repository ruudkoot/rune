# structure Posix.Process

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Posix.Process**

|  |  |
| --- | --- |
| Signature | [`POSIX_PROCESS`](../sig/POSIX_PROCESS.md) |
| Status | optional |
| Members | 21 |
| Tests | 52 checks |
| Source | [lib/basis/posix\_process.sml](../../../../lib/basis/posix_process.sml) |

## Synopsis

```sml
structure Posix.Process : POSIX_PROCESS
```

Posix.Process: making processes, waiting for them, and signalling them.

## Members

What each means is on [`POSIX_PROCESS`](../sig/POSIX_PROCESS.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| datatype | [`exit_status`](../sig/POSIX_PROCESS.md#type-exit_status) | `W_EXITED` &#124; `W_EXITSTATUS` &#124; `W_SIGNALED` &#124; `W_STOPPED` |
| datatype | [`killpid_arg`](../sig/POSIX_PROCESS.md#type-killpid_arg) | `K_PROC` &#124; `K_SAME_GROUP` &#124; `K_GROUP` |
| type | [`pid`](../sig/POSIX_PROCESS.md#type-pid) | *a type of its own* |
| type | [`signal`](../sig/POSIX_PROCESS.md#type-signal) | *a type of its own* |
| datatype | [`waitpid_arg`](../sig/POSIX_PROCESS.md#type-waitpid_arg) | `W_ANY_CHILD` &#124; `W_CHILD` &#124; `W_SAME_GROUP` &#124; `W_GROUP` |
| val | [`alarm`](../sig/POSIX_PROCESS.md#val-alarm) | `Time.time -> Time.time` |
| val | [`exec`](../sig/POSIX_PROCESS.md#val-exec) | `string * string list -> 'a` |
| val | [`exece`](../sig/POSIX_PROCESS.md#val-exece) | `string * string list * string list -> 'b` |
| val | [`execp`](../sig/POSIX_PROCESS.md#val-execp) | `string * string list -> 'c` |
| val | [`exit`](../sig/POSIX_PROCESS.md#val-exit) | `Word8.word -> 'd` |
| val | [`fork`](../sig/POSIX_PROCESS.md#val-fork) | `unit -> pid option` |
| val | [`fromStatus`](../sig/POSIX_PROCESS.md#val-fromstatus) | `OS.Process.status -> exit_status` |
| val | [`kill`](../sig/POSIX_PROCESS.md#val-kill) | `killpid_arg * signal -> unit` |
| val | [`pause`](../sig/POSIX_PROCESS.md#val-pause) | `unit -> unit` |
| val | [`pidToWord`](../sig/POSIX_PROCESS.md#val-pidtoword) | `pid -> word` |
| val | [`sleep`](../sig/POSIX_PROCESS.md#val-sleep) | `Time.time -> Time.time` |
| val | [`wait`](../sig/POSIX_PROCESS.md#val-wait) | `unit -> pid * exit_status` |
| val | [`waitpid`](../sig/POSIX_PROCESS.md#val-waitpid) | `waitpid_arg * W.flags list -> pid * exit_status` |
| val | [`waitpid_nh`](../sig/POSIX_PROCESS.md#val-waitpid_nh) | `waitpid_arg * W.flags list -> (pid * exit_status) option` |
| val | [`wordToPid`](../sig/POSIX_PROCESS.md#val-wordtopid) | `word -> pid` |
| structure | [`W`](../str/Posix.Process.W.md) | [`BIT_FLAGS`](../sig/BIT_FLAGS.md) |

## Notes

### alarm

> **Reading** `Posix.Process.alarm/zero-cancels`. A time of zero asks for no
> alarm, as POSIX has it, so it cancels the outstanding one and still
> reports the time that was left of it.

### exec

> **Reading** `Posix.Process.exec/args-and-path`. The first item of `args` is
> the new program's argument zero and is passed as it stands, not replaced
> by `path`. And `path` is a pathname: a name with no slash in it is not
> looked for along `PATH`, which is what [`execp`](../sig/POSIX_PROCESS.md#val-execp) is for.

### fork

> **Implementation** `Posix.Process.fork/a-second-vm-where-there-is-none`.
> Windows has no [`fork`](../sig/POSIX_PROCESS.md#val-fork). There the VM starts a second one of itself and
> hands it this one's whole state -- the heap, the stacks, the program,
> the open files, the sockets and the directory streams -- and the child
> carries on from the [`fork`](../sig/POSIX_PROCESS.md#val-fork) as a copy of the process would. That costs
> about 12 milliseconds, and 3 more for each megabyte of live data, where
> a [`fork`](../sig/POSIX_PROCESS.md#val-fork) the kernel makes costs almost nothing.

> **Limitation** `Posix.Process.fork/read-ahead-of-a-pipe`. Where the [`fork`](../sig/POSIX_PROCESS.md#val-fork)
> is that second VM, what the C library has read ahead from a pipe or a
> terminal, and the program has not taken yet, stays with the parent
> alone: an input that can seek is put back to where the program had
> read, and a pipe cannot be. A [`fork`](../sig/POSIX_PROCESS.md#val-fork) the kernel makes gives the child a
> copy of it.

### fromStatus

> **Implementation** `Posix.Process.fromStatus/status-encoding`. An
> [`OS.Process.status`](../sig/OS_PROCESS.md#type-status) is an `int`: the exit code of a process that ended of
> itself, 256 and the number of the signal that ended it, or 512 and the
> number of the signal that stopped it.

### sleep

> **Reading** `Posix.Process.sleep/time-left`. The page does not say what the
> result is; it is POSIX's "time left", which is zero when the wait ran
> out and the rest when a signal cut it short.

<details><summary>Other implementations (4)</summary>

- **Poly/ML 5.9.2** &mdash; a forked child that calls Posix.Process.exit (or OS.Process.exit) never ends
- **MLton, Poly/ML** &mdash; fromStatus OS.Process.failure is W\_SIGNALED, not W\_EXITSTATUS of a non-zero value
- **SML/NJ** &mdash; OS.Process.system returns failure (W\_EXITSTATUS 1) for a command that a signal ended
- **Poly/ML** &mdash; a forked child that pauses is not ended by the signal (alrm, usr1) that ends the same pause in the main process

</details>

---

<sub>Generated by runedoc from lib/basis/posix\_process.sml; do not edit.</sub>
