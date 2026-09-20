# signature POSIX_PROC_ENV

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **POSIX_PROC_ENV**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 30 of 30 entries documented |
| Tests | 65 checks of 26 entries |
| Source | [lib/basis/sig\_posix\_proc\_env.sml](../../../../lib/basis/sig_posix_proc_env.sml) |

## Synopsis

```sml
signature POSIX_PROC_ENV
structure Posix.ProcEnv : POSIX_PROC_ENV  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.ProcEnv` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

The process's own identity: who it is, who owns it, which group and
session it belongs to, and what its environment holds.

The user and group identities come in two kinds. The \*real\* one is who
started the process; the \*effective\* one is whose permissions it acts
with, and the two differ for a program whose set-user-id bit is set. A
process may set them back to what they already are, and only a privileged
process may set them to anything else.

[`uname`](#val-uname), [`time`](#val-time), [`times`](#val-times) and [`sysconf`](#val-sysconf) ask the system about itself rather
than about the process.

> **Erratum** `POSIX_PROC_ENV/flexible-types`. The types [`pid`](#type-pid) and [`file_desc`](#type-file_desc)
> are left flexible here, as on the page; [`POSIX`](../sig/POSIX.md) fixes [`pid`](#type-pid) to
> [`Posix.Process.pid`](../sig/POSIX_PROCESS.md#type-pid), and [`file_desc`](#type-file_desc) is the one `FileSys` and [`IO`](../sig/IO.md) use.

> **Implementation** `Posix.ProcEnv/what-a-check-can-expect`. What these report
> is whatever `id`, [`uname`](#val-uname), `date` and `getconf` report on the machine, so
> that is what the suite compares them with. The test runner gives every
> program `/dev/null` for its standard input, so no descriptor a check sees
> is a terminal.

## Interface

<pre>
signature POSIX_PROC_ENV =
sig
  eqtype <a href="#type-pid">pid</a>

  eqtype <a href="#type-uid">uid</a>

  eqtype <a href="#type-gid">gid</a>

  eqtype <a href="#type-file_desc">file_desc</a>

  val <a href="#val-uidtoword">uidToWord</a> : uid -&gt; SysWord.word

  val <a href="#val-wordtouid">wordToUid</a> : SysWord.word -&gt; uid

  val <a href="#val-gidtoword">gidToWord</a> : gid -&gt; SysWord.word

  val <a href="#val-wordtogid">wordToGid</a> : SysWord.word -&gt; gid

  val <a href="#val-getpid">getpid</a> : unit -&gt; pid

  val <a href="#val-getppid">getppid</a> : unit -&gt; pid

  val <a href="#val-getuid">getuid</a> : unit -&gt; uid

  val <a href="#val-geteuid">geteuid</a> : unit -&gt; uid

  val <a href="#val-getgid">getgid</a> : unit -&gt; gid

  val <a href="#val-getegid">getegid</a> : unit -&gt; gid

  val <a href="#val-setuid">setuid</a> : uid -&gt; unit

  val <a href="#val-setgid">setgid</a> : gid -&gt; unit

  val <a href="#val-getgroups">getgroups</a> : unit -&gt; gid list

  val <a href="#val-getlogin">getlogin</a> : unit -&gt; string

  val <a href="#val-getpgrp">getpgrp</a> : unit -&gt; pid

  val <a href="#val-setsid">setsid</a> : unit -&gt; pid

  val <a href="#val-setpgid">setpgid</a> : {<a href="#fld-setpgid.pid">pid</a> : pid option, <a href="#fld-setpgid.pgid">pgid</a> : pid option} -&gt; unit

  val <a href="#val-uname">uname</a> : unit -&gt; (string * string) list

  val <a href="#val-time">time</a> : unit -&gt; Time.time

  val <a href="#val-times">times</a> : unit
              -&gt; {<a href="#fld-times.elapsed">elapsed</a> : Time.time,
                  <a href="#fld-times.utime">utime</a> : Time.time,
                  <a href="#fld-times.stime">stime</a> : Time.time,
                  <a href="#fld-times.cutime">cutime</a> : Time.time,
                  <a href="#fld-times.cstime">cstime</a> : Time.time}

  val <a href="#val-getenv">getenv</a> : string -&gt; string option

  val <a href="#val-environ">environ</a> : unit -&gt; string list

  val <a href="#val-ctermid">ctermid</a> : unit -&gt; string

  val <a href="#val-ttyname">ttyname</a> : file_desc -&gt; string

  val <a href="#val-isatty">isatty</a> : file_desc -&gt; bool

  val <a href="#val-sysconf">sysconf</a> : string -&gt; SysWord.word
end
</pre>

### <a name="type-pid"></a>`pid`

```sml
eqtype pid
```

The type of the number that names a process, the one of [`Posix.Process`](../sig/POSIX.md#str-process).

### <a name="type-uid"></a>`uid`

```sml
eqtype uid
```

The type of the number that names a user.

> **Deviation** `Posix.ProcEnv.uid/is-an-int`. The specification leaves the
> type abstract; in Rune it is `int`, and the structure is not sealed.

### <a name="type-gid"></a>`gid`

```sml
eqtype gid
```

The type of the number that names a group.

### <a name="type-file_desc"></a>`file_desc`

```sml
eqtype file_desc
```

The type of an open file descriptor, the one of [`Posix.FileSys`](../sig/POSIX.md#str-filesys).

### <a name="val-uidtoword"></a>`uidToWord`

```sml
val uidToWord : uid -> SysWord.word
```

`uidToWord u` is the number of the user `u`.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `wordToUid`

</details>

### <a name="val-wordtouid"></a>`wordToUid`

```sml
val wordToUid : SysWord.word -> uid
```

`wordToUid w` is the user numbered `w`, whether or not there is such a user.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `no-validation`

</details>

### <a name="val-gidtoword"></a>`gidToWord`

```sml
val gidToWord : gid -> SysWord.word
```

`gidToWord g` is the number of the group `g`.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `wordToGid`

</details>

### <a name="val-wordtogid"></a>`wordToGid`

```sml
val wordToGid : SysWord.word -> gid
```

`wordToGid w` is the group numbered `w`.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `no-validation`

</details>

### <a name="val-getpid"></a>`getpid`

```sml
val getpid : unit -> pid
```

`getpid ()` is the number of this process.

<details><summary>Tests (3)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `PPID-of-shell` &middot; `stable` &middot; `of-child-differs`

</details>

### <a name="val-getppid"></a>`getppid`

```sml
val getppid : unit -> pid
```

`getppid ()` is the number of the process that made this one.

<details><summary>Tests (2)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `of-child` &middot; `not-self`

</details>

### <a name="val-getuid"></a>`getuid`

```sml
val getuid : unit -> uid
```

`getuid ()` is the user that started this process.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `id-ru`

</details>

### <a name="val-geteuid"></a>`geteuid`

```sml
val geteuid : unit -> uid
```

`geteuid ()` is the user whose permissions this process acts with.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `id-u`

</details>

### <a name="val-getgid"></a>`getgid`

```sml
val getgid : unit -> gid
```

`getgid ()` is the group of the user that started this process.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `id-rg`

</details>

### <a name="val-getegid"></a>`getegid`

```sml
val getegid : unit -> gid
```

`getegid ()` is the group whose permissions this process acts with.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `id-g`

</details>

### <a name="val-setuid"></a>`setuid`

```sml
val setuid : uid -> unit
```

`setuid u` makes `u` the user of this process.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the process may not become `u`.

> **Reading** `Posix.ProcEnv.setuid/own-is-allowed`. Setting the user to the
> one the process already has is allowed and changes nothing. Becoming
> another user, the superuser above all, is refused unless the process is
> privileged already.

<details><summary>Tests (2)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `own` &middot; `root-raises`

</details>

### <a name="val-setgid"></a>`setgid`

```sml
val setgid : gid -> unit
```

`setgid g` makes `g` the group of this process.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the process may not take the group `g`.

<details><summary>Tests (2)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `own` &middot; `root-raises`

</details>

### <a name="val-getgroups"></a>`getgroups`

```sml
val getgroups : unit -> gid list
```

`getgroups ()` is the supplementary groups of this process.

> **Implementation** `Posix.ProcEnv.getgroups/compared-with-id-G`. The suite
> compares the list with what `id -G` prints, which also lists the
> effective group, so that group is added before comparing.

<details><summary>Tests (2)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `in-id-G` &middot; `id-G-in-them`

</details>

### <a name="val-getlogin"></a>`getlogin`

```sml
val getlogin : unit -> string
```

`getlogin ()` is the name the user logged in under.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the system does not know it.

> **Reading** `Posix.ProcEnv.getlogin/may-not-be-known`. Without a terminal
> the system may have no login name to give; the suite accepts either
> [`OS.SysErr`](../sig/OS.md#exn-syserr) or a name that is a user of the machine.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `user-or-SysErr`

</details>

### <a name="val-getpgrp"></a>`getpgrp`

```sml
val getpgrp : unit -> pid
```

`getpgrp ()` is the process group this process is in.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `inherited`

</details>

### <a name="val-setsid"></a>`setsid`

```sml
val setsid : unit -> pid
```

`setsid ()` starts a new session with this process alone in it, and is its new process group.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if this process already leads a process group.

> **Reading** `Posix.ProcEnv.setsid/group-is-the-pid`. The process group it
> returns is the process's own number, since the process becomes the
> leader of a group of its own.

<details><summary>Tests (2)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `child` &middot; `group-leader-raises`

</details>

### <a name="val-setpgid"></a>`setpgid`

```sml
val setpgid : {pid : pid option, pgid : pid option} -> unit
```

`setpgid {pid, pgid}` puts the process `pid` into the process group `pgid`, `NONE` meaning this process.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the move is refused.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-setpgid.pid"></a>`pid` | `pid option` |  |
| <a name="fld-setpgid.pgid"></a>`pgid` | `pid option` |  |

<details><summary>Tests (5)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `NONE-NONE` &middot; `SOME-NONE` &middot; `NONE-SOME` &middot; `SOME-SOME` &middot; `no-such-process` (raises)

</details>

### <a name="val-uname"></a>`uname`

```sml
val uname : unit -> (string * string) list
```

`uname ()` is what the system says about itself, as pairs of a field and its value.

The fields are `"sysname"`, `"nodename"`, `"release"`, `"version"` and
`"machine"`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the system cannot be asked.

<details><summary>Tests (6)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `sysname` &middot; `nodename` &middot; `release` &middot; `version` &middot; `machine` &middot; `names-once`

</details>

### <a name="val-time"></a>`time`

```sml
val time : unit -> Time.time
```

`time ()` is the time now, as [`Time.now`](../sig/TIME.md#val-now) gives it.

<details><summary>Tests (2)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `now` &middot; `date`

</details>

### <a name="val-times"></a>`times`

```sml
val times : unit
            -> {elapsed : Time.time,
                utime : Time.time,
                stime : Time.time,
                cutime : Time.time,
                cstime : Time.time}
```

`times ()` is how much time this process and the children it has waited for have used.

`elapsed` is wall-clock time from a fixed point in the past, `utime` and
`stime` this process's own user and system time, and `cutime` and
`cstime` those of the children it has waited for.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-times.elapsed"></a>`elapsed` | `Time.time` |  |
| <a name="fld-times.utime"></a>`utime` | `Time.time` |  |
| <a name="fld-times.stime"></a>`stime` | `Time.time` |  |
| <a name="fld-times.cutime"></a>`cutime` | `Time.time` |  |
| <a name="fld-times.cstime"></a>`cstime` | `Time.time` |  |

<details><summary>Tests (4)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `not-negative` &middot; `elapsed-is-wall-time` &middot; `cpu-time-grows` &middot; `children`

</details>

### <a name="val-getenv"></a>`getenv`

```sml
val getenv : string -> string option
```

`getenv name` is `SOME` of the value of the environment variable `name`, or `NONE`.

<details><summary>Tests (3)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `PATH` &middot; `unset` &middot; `shell`

</details>

### <a name="val-environ"></a>`environ`

```sml
val environ : unit -> string list
```

`environ ()` is the whole environment, each entry written `"name=value"`.

<details><summary>Tests (4)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `has-PATH` &middot; `name-value` &middot; `getenv-agrees` &middot; `no-unset`

</details>

### <a name="val-ctermid"></a>`ctermid`

```sml
val ctermid : unit -> string
```

`ctermid ()` is the path of this process's controlling terminal, or the empty string when it has none.

<details><summary>Tests (1)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `pathname`

</details>

### <a name="val-ttyname"></a>`ttyname`

```sml
val ttyname : file_desc -> string
```

`ttyname fd` is the path of the terminal that `fd` is open on.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not a terminal.

<details><summary>Tests (2)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `dev-null` (raises) &middot; `bad-descriptor` (raises)

</details>

### <a name="val-isatty"></a>`isatty`

```sml
val isatty : file_desc -> bool
```

`isatty fd` is `true` when `fd` is open on a terminal.

<details><summary>Tests (3)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `dev-null` &middot; `bad-descriptor` &middot; `pipe`

</details>

### <a name="val-sysconf"></a>`sysconf`

```sml
val sysconf : string -> SysWord.word
```

`sysconf name` is the value the system gives for the limit or option `name`, such as `"CLK_TCK"`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the system does not know `name`.

> **Reading** `Posix.ProcEnv.sysconf/no-limit-raises`. A variable the system
> knows but leaves unbounded is reported the same way as an unknown one --
> the call gives `~1` and sets no `errno` \-- so this raises for both.

<details><summary>Tests (12)</summary>

For `Posix.ProcEnv`, in [tests/basis/posix\_procenv.sml](../../../../tests/basis/posix_procenv.sml): `ARG_MAX` &middot; `CHILD_MAX` &middot; `CLK_TCK` &middot; `NGROUPS_MAX` &middot; `OPEN_MAX` &middot; `STREAM_MAX` &middot; `JOB_CONTROL` &middot; `SAVED_IDS` &middot; `VERSION` &middot; `TZNAME_MAX` &middot; `CLK_TCK-positive` &middot; `unknown` (raises)

</details>

## See also

[`POSIX`](../sig/POSIX.md), [`POSIX_SYS_DB`](../sig/POSIX_SYS_DB.md), [`POSIX_PROCESS`](../sig/POSIX_PROCESS.md), [`OS_PROCESS`](../sig/OS_PROCESS.md), [`TIME`](../sig/TIME.md)

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_proc\_env.sml; do not edit.</sub>
