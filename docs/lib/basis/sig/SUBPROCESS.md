# signature SUBPROCESS

[The Standard ML Basis Library](../README.md) &rsaquo; The runtime &rsaquo; **SUBPROCESS**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 8 of 8 entries documented |
| Tests | 14 checks of 5 entries |
| Source | [lib/basis/subprocess\_sig.sml](../../../../lib/basis/subprocess_sig.sml) |

## Synopsis

```sml
signature SUBPROCESS
structure Subprocess : SUBPROCESS  (* extension *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Subprocess`](../str/Subprocess.md) | Subprocess: children started in a directory, a group and under limits, and waited for with what they cost (docs/plans/unit-testing.md, M2). | [lib/basis/subprocess.sml](../../../../lib/basis/subprocess.sml) |

Programs started as children that a runner of tests supervises
(docs/plans/unit-testing.md, M2): in a directory of their own, in a
process group (a job on Windows) that can be ended as one, under limits,
with the signals at their default actions, and waited for with what they
cost.

[`Unix`](../str/Unix.md) and [`Posix.Process`](../str/Posix.Process.md) start and reap programs too. This adds what a
runner needs and they lack: the directory, the group, the limits and the
signals at the start, and the processor time and the memory at the end.

This signature is Rune's own. On Windows a job has limits of memory and of
processor time only, a signal's action is always the default, and ending
a group ends its job.

## Interface

<pre>
signature SUBPROCESS =
sig
  type <a href="#type-pid">pid</a> = int
  type <a href="#type-limits">limits</a> = {<a href="#fld-limits.addressspace">addressSpace</a> : int option, <a href="#fld-limits.cputime">cpuTime</a> : int option, <a href="#fld-limits.filesize">fileSize</a> : int option, <a href="#fld-limits.core">core</a> : int option}
  val <a href="#val-unlimited">unlimited</a> : limits
  type <a href="#type-ended">ended</a> = {<a href="#fld-ended.pid">pid</a> : pid, <a href="#fld-ended.status">status</a> : Posix.Process.exit_status, <a href="#fld-ended.user">user</a> : Time.time,
                <a href="#fld-ended.system">system</a> : Time.time, <a href="#fld-ended.peakresident">peakResident</a> : int}
  val <a href="#val-spawn">spawn</a> : {<a href="#fld-spawn.program">program</a> : string, <a href="#fld-spawn.args">args</a> : string list, <a href="#fld-spawn.env">env</a> : string list option, <a href="#fld-spawn.search">search</a> : bool,
               <a href="#fld-spawn.dir">dir</a> : string option, <a href="#fld-spawn.stdin">stdin</a> : int option, <a href="#fld-spawn.stdout">stdout</a> : int option, <a href="#fld-spawn.stderr">stderr</a> : int option,
               <a href="#fld-spawn.group">group</a> : bool, <a href="#fld-spawn.limits">limits</a> : limits} -&gt; pid
  val <a href="#val-wait">wait</a> : pid option -&gt; ended
  val <a href="#val-poll">poll</a> : pid option -&gt; ended option
  val <a href="#val-kill">kill</a> : pid * Posix.Signal.signal -&gt; unit
end
</pre>

### <a name="type-pid"></a>`pid`

```sml
type pid = int
```

A child's process: its number, as the system gives it.

A descriptor is given by its number too ([`Posix.FileSys.fdToWord`](../sig/POSIX_FILE_SYS.md#val-fdtoword)):
[`Posix`](../str/Posix.md)'s types are its own, and this structure is not part of it.

### <a name="type-limits"></a>`limits`

```sml
type limits = {addressSpace : int option, cpuTime : int option, fileSize : int option, core : int option}
```

Limits on a child, each `NONE` for none.

They are the bytes of address space it may hold, the seconds of
processor time it may take, the bytes of a file it may write (it gets
SIGXFSZ beyond them), and the bytes of a core dump (0 for none).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-limits.addressspace"></a>`addressSpace` | `int option` |  |
| <a name="fld-limits.cputime"></a>`cpuTime` | `int option` |  |
| <a name="fld-limits.filesize"></a>`fileSize` | `int option` |  |
| <a name="fld-limits.core"></a>`core` | `int option` |  |

### <a name="val-unlimited"></a>`unlimited`

```sml
val unlimited : limits
```

No limits beyond this program's own.

**Example** `#addressSpace unlimited = NONE`

<details><summary>Tests (1)</summary>

For `Subprocess`, in [tests/basis/subprocess.sml](../../../../tests/basis/subprocess.sml): `no-limits`

</details>

### <a name="type-ended"></a>`ended`

```sml
type ended = {pid : pid, status : Posix.Process.exit_status, user : Time.time,
              system : Time.time, peakResident : int}
```

How a child ended, and what it cost: its user and system processor
time, and the most memory it held resident, in kilobytes (0 where the
system does not say).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-ended.pid"></a>`pid` | `pid` |  |
| <a name="fld-ended.status"></a>`status` | `Posix.Process.exit_status` |  |
| <a name="fld-ended.user"></a>`user` | `Time.time` |  |
| <a name="fld-ended.system"></a>`system` | `Time.time` |  |
| <a name="fld-ended.peakresident"></a>`peakResident` | `int` |  |

### <a name="val-spawn"></a>`spawn`

```sml
val spawn : {program : string, args : string list, env : string list option, search : bool,
             dir : string option, stdin : int option, stdout : int option, stderr : int option,
             group : bool, limits : limits} -> pid
```

`spawn {program, args, env, search, dir, stdin, stdout, stderr, group, limits}`
starts `program` as a child, and is its process.

`args` are its arguments, its name first, as [`Posix.Process.exec`](../sig/POSIX_PROCESS.md#val-exec) takes
them; `env` its environment (`NONE`: this program's); `search` looks
for `program` on `PATH`; `dir` is the directory it starts in (`NONE`:
this program's); the three descriptors, by number, become its standard
input, output and error (`NONE`: this program's own); `group` puts it in a
process group of its own, which [`kill`](#val-kill) ends as one. Its signals start
at their default actions. A program that cannot be run is, on POSIX, a
child that exits with 126.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) when the child cannot be started.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-spawn.program"></a>`program` | `string` |  |
| <a name="fld-spawn.args"></a>`args` | `string list` |  |
| <a name="fld-spawn.env"></a>`env` | `string list option` |  |
| <a name="fld-spawn.search"></a>`search` | `bool` |  |
| <a name="fld-spawn.dir"></a>`dir` | `string option` |  |
| <a name="fld-spawn.stdin"></a>`stdin` | `int option` |  |
| <a name="fld-spawn.stdout"></a>`stdout` | `int option` |  |
| <a name="fld-spawn.stderr"></a>`stderr` | `int option` |  |
| <a name="fld-spawn.group"></a>`group` | `bool` |  |
| <a name="fld-spawn.limits"></a>`limits` | `limits` |  |

<details><summary>Tests (5)</summary>

For `Subprocess`, in [tests/basis/subprocess.sml](../../../../tests/basis/subprocess.sml): `env` &middot; `search` &middot; `stdout` &middot; `file-size-limit` &middot; `cpu-time-limit`

</details>

### <a name="val-wait"></a>`wait`

```sml
val wait : pid option -> ended
```

`wait pid` waits for the child `pid` to end (`NONE`: any child), and
is how it ended and what it cost.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) when there is no such child.

<details><summary>Tests (6)</summary>

For `Subprocess`, in [tests/basis/subprocess.sml](../../../../tests/basis/subprocess.sml): `exit-0` &middot; `exit-7` &middot; `any-child` &middot; `no-child` &middot; `user-time` &middot; `peak-resident`

</details>

### <a name="val-poll"></a>`poll`

```sml
val poll : pid option -> ended option
```

`poll pid` is `wait pid` if the child has ended, and `NONE` at once if
it has not.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) when there is no such child.

<details><summary>Tests (1)</summary>

For `Subprocess`, in [tests/basis/subprocess.sml](../../../../tests/basis/subprocess.sml): `running`

</details>

### <a name="val-kill"></a>`kill`

```sml
val kill : pid * Posix.Signal.signal -> unit
```

`kill (pid, s)` sends the signal `s` to the process group of the child
`pid`, which [`spawn`](#val-spawn) made with `group`.

The group is the child and every process it started. On Windows it ends
the child's job.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) when there is no such group.

<details><summary>Tests (1)</summary>

For `Subprocess`, in [tests/basis/subprocess.sml](../../../../tests/basis/subprocess.sml): `the-group`

</details>

---

<sub>Generated by runedoc from lib/basis/subprocess\_sig.sml; do not edit.</sub>
