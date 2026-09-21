# signature POSIX_ERROR

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **POSIX_ERROR**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 49 of 49 entries documented |
| Tests | 81 checks of 49 entries |
| Source | [lib/basis/sig\_posix\_error.sml](../../../../lib/basis/sig_posix_error.sml) |

## Synopsis

```sml
signature POSIX_ERROR
structure Posix.Error : POSIX_ERROR  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.Error` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

The conditions the system reports when a call fails, and their names.

A failing POSIX call raises [`OS.SysErr`](../sig/OS.md#exn-syserr) with a [`syserror`](#val-syserror), which is the
`errno` the call left behind. The values below are the conditions POSIX
names; comparing with one of them is how a program asks why a call failed:

```f () handle OS.SysErr (_, SOME e) => if e = Posix.Error.noent then ... else ...```

Which condition a call reports is POSIX's business, not this library's,
and POSIX leaves some of it open: removing a directory that is not empty
may give [`exist`](#val-exist) or [`notempty`](#val-notempty), and a system may report something no name
here covers. [`errorName`](#val-errorname) names those too.

> **Erratum** `POSIX_ERROR.syserror/spec-writes-OS.Process`. The
> page writes `eqtype syserror = OS.Process.syserror`; [`OS.Process`](../sig/OS.md#str-process) has no
> such type, the description says it "is identical to the type
> [`OS.syserror`](../sig/OS.md#val-syserror)", and `eqtype t = ty` is not a specification SML allows. It
> is written `type syserror = OS.syserror`, which admits equality.

> **Reading** `Posix.Error/which-error-is-posix's`. Which condition a failing
> call reports is prescribed by POSIX and not by this library; where POSIX
> allows two, the suite accepts either.

## Contents

[The conditions POSIX names](#the-conditions-posix-names)

## Interface

<pre>
signature POSIX_ERROR =
sig
  type <a href="#type-syserror">syserror</a> = OS.syserror

  val <a href="#val-toword">toWord</a> : syserror -&gt; SysWord.word

  val <a href="#val-fromword">fromWord</a> : SysWord.word -&gt; syserror

  val <a href="#val-errormsg">errorMsg</a> : syserror -&gt; string

  val <a href="#val-errorname">errorName</a> : syserror -&gt; string

  val <a href="#val-syserror">syserror</a> : string -&gt; syserror option

  val <a href="#val-acces">acces</a> : syserror

  val <a href="#val-again">again</a> : syserror

  val <a href="#val-badf">badf</a> : syserror

  val <a href="#val-badmsg">badmsg</a> : syserror

  val <a href="#val-busy">busy</a> : syserror

  val <a href="#val-canceled">canceled</a> : syserror

  val <a href="#val-child">child</a> : syserror

  val <a href="#val-deadlk">deadlk</a> : syserror

  val <a href="#val-dom">dom</a> : syserror

  val <a href="#val-exist">exist</a> : syserror

  val <a href="#val-fault">fault</a> : syserror

  val <a href="#val-fbig">fbig</a> : syserror

  val <a href="#val-inprogress">inprogress</a> : syserror

  val <a href="#val-intr">intr</a> : syserror

  val <a href="#val-inval">inval</a> : syserror

  val <a href="#val-io">io</a> : syserror

  val <a href="#val-isdir">isdir</a> : syserror

  val <a href="#val-loop">loop</a> : syserror

  val <a href="#val-mfile">mfile</a> : syserror

  val <a href="#val-mlink">mlink</a> : syserror

  val <a href="#val-msgsize">msgsize</a> : syserror

  val <a href="#val-nametoolong">nametoolong</a> : syserror

  val <a href="#val-nfile">nfile</a> : syserror

  val <a href="#val-nodev">nodev</a> : syserror

  val <a href="#val-noent">noent</a> : syserror

  val <a href="#val-noexec">noexec</a> : syserror

  val <a href="#val-nolck">nolck</a> : syserror

  val <a href="#val-nomem">nomem</a> : syserror

  val <a href="#val-nospc">nospc</a> : syserror

  val <a href="#val-nosys">nosys</a> : syserror

  val <a href="#val-notdir">notdir</a> : syserror

  val <a href="#val-notempty">notempty</a> : syserror

  val <a href="#val-notsup">notsup</a> : syserror

  val <a href="#val-notty">notty</a> : syserror

  val <a href="#val-nxio">nxio</a> : syserror

  val <a href="#val-perm">perm</a> : syserror

  val <a href="#val-pipe">pipe</a> : syserror

  val <a href="#val-range">range</a> : syserror

  val <a href="#val-rofs">rofs</a> : syserror

  val <a href="#val-spipe">spipe</a> : syserror

  val <a href="#val-srch">srch</a> : syserror

  val <a href="#val-toobig">toobig</a> : syserror

  val <a href="#val-xdev">xdev</a> : syserror
end
</pre>

### <a name="type-syserror"></a>`syserror`

```sml
type syserror = OS.syserror
```

The type of a condition the system reports: the [`syserror`](#val-syserror) of [`OS`](../sig/OS.md).

> **Deviation** `Posix.Error.syserror/is-an-int`. It is the `errno` of the
> system, an `int`, and the type is not made abstract, so that shows.

<details><summary>Tests (4)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `inverts-errorName-all` &middot; `unknown-name` &middot; `empty-name` &middot; `is-OS.syserror`

</details>

### <a name="val-toword"></a>`toWord`

```sml
val toWord : syserror -> SysWord.word
```

`toWord e` is the number the system gives `e`, its `errno` value.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `distinct-words` &middot; `nonzero`

</details>

### <a name="val-fromword"></a>`fromWord`

```sml
val fromWord : SysWord.word -> syserror
```

`fromWord w` is the condition whose `errno` value is `w`.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `no-validation` &middot; `of-toWord`

</details>

### <a name="val-errormsg"></a>`errorMsg`

```sml
val errorMsg : syserror -> string
```

`errorMsg e` is the text the system gives for `e`, meant for a person to read.

<details><summary>Tests (4)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `is-OS.errorMsg` &middot; `nonempty` &middot; `differ` &middot; `of-SysErr`

</details>

### <a name="val-errorname"></a>`errorName`

```sml
val errorName : syserror -> string
```

`errorName e` is a short name for `e`, meant for a program.

> **Implementation** `Posix.Error.errorName/the-posix-names`. For the
> conditions POSIX names it is the name below -- `"noent"` for [`noent`](#val-noent) \--
> and for the others it is the name [`OS.errorName`](../sig/OS.md#val-errorname) invents.

**Example** `errorName noent = "noent"`

<details><summary>Tests (4)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `distinct-errors` &middot; `distinct-names` &middot; `badmsg` &middot; `toobig-not-2big`

</details>

### <a name="val-syserror"></a>`syserror`

```sml
val syserror : string -> syserror option
```

`syserror s` is `SOME` of the condition that [`errorName`](#val-errorname) calls `s`, or `NONE`.

**Law** `syserror (errorName e) = SOME e` for every condition, named here
or not.

**Example** `syserror "noent" = SOME noent`

<details><summary>Tests (4)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `inverts-errorName-all` &middot; `unknown-name` &middot; `empty-name` &middot; `is-OS.syserror`

</details>

## The conditions POSIX names

### <a name="val-acces"></a>`acces`

```sml
val acces : syserror
```

Permission is refused.

> **Implementation** `Posix.Error.acces/not-for-the-superuser`. Permission
> bits do not stop a privileged process, so the suite's checks of this and
> of [`perm`](#val-perm) hold for an ordinary user and pass trivially as root.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `open-unreadable-file`

</details>

### <a name="val-again"></a>`again`

```sml
val again : syserror
```

Nothing is ready; try again.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-badf"></a>`badf`

```sml
val badf : syserror
```

The file descriptor is not open, or not open the right way.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; Posix.IO.close of a descriptor that is already closed raises no exception

</details>

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `close-twice`

</details>

### <a name="val-badmsg"></a>`badmsg`

```sml
val badmsg : syserror
```

The message is not of the right kind.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-busy"></a>`busy`

```sml
val busy : syserror
```

What was asked for is in use.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-canceled"></a>`canceled`

```sml
val canceled : syserror
```

The operation was cancelled.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-child"></a>`child`

```sml
val child : syserror
```

The process has no child to wait for.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `wait-without-children`

</details>

### <a name="val-deadlk"></a>`deadlk`

```sml
val deadlk : syserror
```

Waiting would deadlock.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-dom"></a>`dom`

```sml
val dom : syserror
```

The argument is outside the domain of the function.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-exist"></a>`exist`

```sml
val exist : syserror
```

The file is there already.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `mkDir-twice`

</details>

### <a name="val-fault"></a>`fault`

```sml
val fault : syserror
```

An address given to the system is not one the process may use.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-fbig"></a>`fbig`

```sml
val fbig : syserror
```

The file would grow past what the system or the process allows.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-inprogress"></a>`inprogress`

```sml
val inprogress : syserror
```

The operation has started and is not finished.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-intr"></a>`intr`

```sml
val intr : syserror
```

A signal arrived before anything was done.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-inval"></a>`inval`

```sml
val inval : syserror
```

An argument is not one the call accepts.

> **Implementation** `Posix.Error.inval/rename-into-itself`. Renaming a
> directory into itself is taken to report this condition.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `rename-into-itself`

</details>

### <a name="val-io"></a>`io`

```sml
val io : syserror
```

The device reported a failure.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-isdir"></a>`isdir`

```sml
val isdir : syserror
```

The name is a directory where one is not allowed.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `open-directory-for-writing`

</details>

### <a name="val-loop"></a>`loop`

```sml
val loop : syserror
```

Too many symbolic links were followed; they may lead in a circle.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `symbolic-link-loop`

</details>

### <a name="val-mfile"></a>`mfile`

```sml
val mfile : syserror
```

The process has as many files open as it may.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-mlink"></a>`mlink`

```sml
val mlink : syserror
```

The file has as many links as it may.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-msgsize"></a>`msgsize`

```sml
val msgsize : syserror
```

The message is longer than may be sent at once.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nametoolong"></a>`nametoolong`

```sml
val nametoolong : syserror
```

The name, or one of its arcs, is too long.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `long-file-name`

</details>

### <a name="val-nfile"></a>`nfile`

```sml
val nfile : syserror
```

The system has as many files open as it may.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nodev"></a>`nodev`

```sml
val nodev : syserror
```

The device does not offer this operation.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-noent"></a>`noent`

```sml
val noent : syserror
```

The name names nothing.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `open-missing-file`

</details>

### <a name="val-noexec"></a>`noexec`

```sml
val noexec : syserror
```

The file is not a program the system can run.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `exec-of-data`

</details>

### <a name="val-nolck"></a>`nolck`

```sml
val nolck : syserror
```

No lock is free.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nomem"></a>`nomem`

```sml
val nomem : syserror
```

There is not enough memory.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nospc"></a>`nospc`

```sml
val nospc : syserror
```

There is no room left on the device.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nosys"></a>`nosys`

```sml
val nosys : syserror
```

The system does not have this call.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-notdir"></a>`notdir`

```sml
val notdir : syserror
```

The name is not a directory where one is needed.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `path-through-file`

</details>

### <a name="val-notempty"></a>`notempty`

```sml
val notempty : syserror
```

The directory is not empty.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `rmDir-nonempty`

</details>

### <a name="val-notsup"></a>`notsup`

```sml
val notsup : syserror
```

The operation is not supported here.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-notty"></a>`notty`

```sml
val notty : syserror
```

The descriptor is not a terminal.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; ttyname of a descriptor that is not a terminal raises SysErr with NONE, not SOME notty

</details>

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `ttyname-of-dev-null`

</details>

### <a name="val-nxio"></a>`nxio`

```sml
val nxio : syserror
```

The device or the address is not there.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-perm"></a>`perm`

```sml
val perm : syserror
```

The operation is not permitted, whatever the permission bits say.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `setuid-root`

</details>

### <a name="val-pipe"></a>`pipe`

```sml
val pipe : syserror
```

A pipe or a socket is written that nobody reads.

> **Reading** `Posix.Error.pipe/or-the-signal`. Writing to such a pipe either
> ends the writer with [`Posix.Signal.pipe`](../sig/POSIX_SIGNAL.md#val-pipe) or, when that signal is ignored
> or caught, fails with this condition; the suite accepts both.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `write-without-reader`

</details>

### <a name="val-range"></a>`range`

```sml
val range : syserror
```

The result is outside the range the type can hold.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-rofs"></a>`rofs`

```sml
val rofs : syserror
```

The file system may only be read.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-spipe"></a>`spipe`

```sml
val spipe : syserror
```

The descriptor cannot be positioned: it is a pipe, a socket or a terminal.

<details><summary>Other implementations (1)</summary>

- **SML/NJ 110.99.9** &mdash; Posix.IO.lseek on a pipe raises another exception than SysErr (spipe); outside the suite the runtime stops with "bogus overflow fault"

</details>

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `lseek-on-pipe`

</details>

### <a name="val-srch"></a>`srch`

```sml
val srch : syserror
```

There is no such process.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `kill-reaped-child`

</details>

### <a name="val-toobig"></a>`toobig`

```sml
val toobig : syserror
```

The argument list is longer than the system allows.

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `exec-huge-argument`

</details>

### <a name="val-xdev"></a>`xdev`

```sml
val xdev : syserror
```

The link would cross from one file system to another.

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

## See also

[`OS`](../sig/OS.md), [`POSIX`](../sig/POSIX.md), [`POSIX_FILE_SYS`](../sig/POSIX_FILE_SYS.md), [`POSIX_IO`](../sig/POSIX_IO.md)

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_error.sml; do not edit.</sub>
