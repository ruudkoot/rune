# structure Posix.ProcEnv

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Posix.ProcEnv**

|  |  |
| --- | --- |
| Signature | [`POSIX_PROC_ENV`](../sig/POSIX_PROC_ENV.md) |
| Status | optional |
| Members | 30 |
| Tests | 60 checks |
| Source | [lib/basis/posix\_procenv.sml](../../../../lib/basis/posix_procenv.sml) |

## Synopsis

```sml
structure Posix.ProcEnv : POSIX_PROC_ENV
```

Posix.ProcEnv: the process and the world it runs in.

## Members

What each means is on [`POSIX_PROC_ENV`](../sig/POSIX_PROC_ENV.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`file_desc`](../sig/POSIX_PROC_ENV.md#type-file_desc) | *a type of its own* |
| type | [`gid`](../sig/POSIX_PROC_ENV.md#type-gid) | *a type of its own* |
| type | [`pid`](../sig/POSIX_PROC_ENV.md#type-pid) | *a type of its own* |
| type | [`uid`](../sig/POSIX_PROC_ENV.md#type-uid) | *a type of its own* |
| val | [`ctermid`](../sig/POSIX_PROC_ENV.md#val-ctermid) | `unit -> string` |
| val | [`environ`](../sig/POSIX_PROC_ENV.md#val-environ) | `unit -> string list` |
| val | [`getegid`](../sig/POSIX_PROC_ENV.md#val-getegid) | `unit -> gid` |
| val | [`getenv`](../sig/POSIX_PROC_ENV.md#val-getenv) | `string -> string option` |
| val | [`geteuid`](../sig/POSIX_PROC_ENV.md#val-geteuid) | `unit -> uid` |
| val | [`getgid`](../sig/POSIX_PROC_ENV.md#val-getgid) | `unit -> gid` |
| val | [`getgroups`](../sig/POSIX_PROC_ENV.md#val-getgroups) | `unit -> gid list` |
| val | [`getlogin`](../sig/POSIX_PROC_ENV.md#val-getlogin) | `unit -> string` |
| val | [`getpgrp`](../sig/POSIX_PROC_ENV.md#val-getpgrp) | `unit -> pid` |
| val | [`getpid`](../sig/POSIX_PROC_ENV.md#val-getpid) | `unit -> pid` |
| val | [`getppid`](../sig/POSIX_PROC_ENV.md#val-getppid) | `unit -> pid` |
| val | [`getuid`](../sig/POSIX_PROC_ENV.md#val-getuid) | `unit -> uid` |
| val | [`gidToWord`](../sig/POSIX_PROC_ENV.md#val-gidtoword) | `gid -> word` |
| val | [`isatty`](../sig/POSIX_PROC_ENV.md#val-isatty) | `file_desc -> bool` |
| val | [`setgid`](../sig/POSIX_PROC_ENV.md#val-setgid) | `gid -> unit` |
| val | [`setpgid`](../sig/POSIX_PROC_ENV.md#val-setpgid) | `{pgid : pid option, pid : pid option} -> unit` |
| val | [`setsid`](../sig/POSIX_PROC_ENV.md#val-setsid) | `unit -> pid` |
| val | [`setuid`](../sig/POSIX_PROC_ENV.md#val-setuid) | `uid -> unit` |
| val | [`sysconf`](../sig/POSIX_PROC_ENV.md#val-sysconf) | `string -> word` |
| val | [`time`](../sig/POSIX_PROC_ENV.md#val-time) | `unit -> Time.time` |
| val | [`times`](../sig/POSIX_PROC_ENV.md#val-times) | `unit -> {cstime : Time.time, cutime : Time.time, elapsed : Time.time, stime : Time.time, utime : Time.time}` |
| val | [`ttyname`](../sig/POSIX_PROC_ENV.md#val-ttyname) | `file_desc -> string` |
| val | [`uidToWord`](../sig/POSIX_PROC_ENV.md#val-uidtoword) | `uid -> word` |
| val | [`uname`](../sig/POSIX_PROC_ENV.md#val-uname) | `unit -> (string * string) list` |
| val | [`wordToGid`](../sig/POSIX_PROC_ENV.md#val-wordtogid) | `word -> gid` |
| val | [`wordToUid`](../sig/POSIX_PROC_ENV.md#val-wordtouid) | `word -> uid` |

## Notes

### 

> **Implementation** `Posix.ProcEnv/what-a-check-can-expect`. What these report
> is whatever `id`, [`uname`](../sig/POSIX_PROC_ENV.md#val-uname), `date` and `getconf` report on the machine, so
> that is what the suite compares them with. The test runner gives every
> program `/dev/null` for its standard input, so no descriptor a check sees
> is a terminal.

### getgroups

> **Implementation** `Posix.ProcEnv.getgroups/compared-with-id-G`. The suite
> compares the list with what `id -G` prints, which also lists the
> effective group, so that group is added before comparing.

### getlogin

> **Reading** `Posix.ProcEnv.getlogin/may-not-be-known`. Without a terminal
> the system may have no login name to give; the suite accepts either
> [`OS.SysErr`](../sig/OS.md#exn-syserr) or a name that is a user of the machine.

### setgid

> **Reading** `Posix.ProcEnv.setgid/own-is-allowed`. As for [`setuid`](../sig/POSIX_PROC_ENV.md#val-setuid): a process
> may always take the group it has, and only a privileged one may take
> another.

### setsid

> **Reading** `Posix.ProcEnv.setsid/group-is-the-pid`. The process group it
> returns is the process's own number, since the process becomes the
> leader of a group of its own.

### setuid

> **Reading** `Posix.ProcEnv.setuid/own-is-allowed`. Setting the user to the
> one the process already has is allowed and changes nothing. Becoming
> another user, the superuser above all, is refused unless the process is
> privileged already.

### sysconf

> **Reading** `Posix.ProcEnv.sysconf/no-limit-raises`. A variable the system
> knows but leaves unbounded is reported the same way as an unknown one --
> the call gives `~1` and sets no `errno` \-- so this raises for both.

<details><summary>Other implementations (2)</summary>

- **SML/NJ 110.99.9 (64-bit)** &mdash; time () is negative: the seconds since the Epoch overflow 32 bits
- **SML/NJ 110.99.9 (64-bit)** &mdash; the elapsed time of times is negative

</details>

---

<sub>Generated by runedoc from lib/basis/posix\_procenv.sml; do not edit.</sub>
