# signature OS

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **OS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 9 of 9 entries documented |
| Tests | 45 checks of 5 entries |
| Source | [lib/basis/sig\_os.sml](../../../../lib/basis/sig_os.sml) |

## Synopsis

```sml
signature OS
structure OS : OS
```

| Implementation |  | Source |
| --- | --- | --- |
| `OS` | OS: the errors of the system, the file system, paths, the process and the I/O descriptors. | [lib/basis/os.sml](../../../../lib/basis/os.sml) |

The operating system: its errors, its file system, its paths, its
processes and its I/O descriptors, gathered into one structure.

The four substructures are what a program uses; what stands here besides
them is the error reporting they share. Every operation of [`OS`](OS.md) that the
system refuses raises [`SysErr`](#exn-syserr), with the text the system gave and a
[`syserror`](#val-syserror) naming the condition.

[`POSIX`](../sig/POSIX.md) goes further for the systems that have it, and [`UNIX`](../sig/UNIX.md) runs other
programs.

> **Erratum** `OS/opaque-in-the-page`. The page declares `structure OS :> OS`, so the types that no `where` clause fixes are abstract; the
> suite matches [`OS`](OS.md) against this signature both transparently and
> opaquely.

## Interface

<pre>
signature OS =
sig
  structure <a href="#str-filesys">FileSys</a> : OS_FILE_SYS

  structure <a href="#str-io">IO</a> : OS_IO

  structure <a href="#str-path">Path</a> : OS_PATH

  structure <a href="#str-process">Process</a> : OS_PROCESS

  eqtype <a href="#type-syserror">syserror</a>

  exception <a href="#exn-syserr">SysErr</a> of string * syserror option

  val <a href="#val-errormsg">errorMsg</a> : syserror -&gt; string

  val <a href="#val-errorname">errorName</a> : syserror -&gt; string

  val <a href="#val-syserror">syserror</a> : string -&gt; syserror option
end
</pre>

### <a name="str-filesys"></a>`FileSys`

```sml
structure FileSys : OS_FILE_SYS
```

A substructure: its members are described on the page of [`OS_FILE_SYS`](../sig/OS_FILE_SYS.md).

The file system: directories, the kind of a file, and its times and sizes.

### <a name="str-io"></a>`IO`

```sml
structure IO : OS_IO
```

A substructure: its members are described on the page of [`OS_IO`](../sig/OS_IO.md).

The descriptors the system knows a stream by, and polling them.

### <a name="str-path"></a>`Path`

```sml
structure Path : OS_PATH
```

A substructure: its members are described on the page of [`OS_PATH`](../sig/OS_PATH.md).

Paths as text, taken apart and put together.

### <a name="str-process"></a>`Process`

```sml
structure Process : OS_PROCESS
```

A substructure: its members are described on the page of [`OS_PROCESS`](../sig/OS_PROCESS.md).

The process: its environment, its exit and the commands it runs.

### <a name="type-syserror"></a>`syserror`

```sml
eqtype syserror
```

The type of a condition the system reports.

> **Deviation** `OS.syserror/is-an-int`. The specification leaves the type
> abstract; in Rune it is the `errno` of the system, an `int`, and the type is not made abstract, so that shows.

<details><summary>Tests (7)</summary>

For `OS`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `inverts-errorName-notdir` &middot; `unknown-name` &middot; `empty-name`

For `OS`, in [tests/basis/os.process\_os.sml](../../../../tests/basis/os.process_os.sml): `errorName-*` &middot; `same-condition` &middot; `not-a-name` &middot; `Posix-errors`

</details>

### <a name="exn-syserr"></a>`SysErr`

```sml
exception SysErr of string * syserror option
```

Raised when the system refuses an operation: the message it gave, and the condition when there is one.

<details><summary>Tests (17)</summary>

For `OS`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `carries-message` &middot; `is-raised` (raises) &middot; `is-not-Fail` &middot; `syserror-option-type` &middot; `cause-of-failed-open` &middot; `failed-open-has-syserror` &middot; `carries-syserror`

For `OS`, in [tests/basis/os.process\_os.sml](../../../../tests/basis/os.process_os.sml): `setup` &middot; `*` &middot; `NONE-form` &middot; `SOME-form` &middot; `exnName` &middot; `is-not-IO.Io` &middot; `remove-missing-is-noent` &middot; `mkDir-existing-is-exist` &middot; `chDir-to-a-file-is-notdir` &middot; `cleanup`

</details>

### <a name="val-errormsg"></a>`errorMsg`

```sml
val errorMsg : syserror -> string
```

`errorMsg e` is the text the system gives for `e`, meant for a person to read.

<details><summary>Tests (7)</summary>

For `OS`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `is-the-message-of-SysErr` &middot; `is-the-message-of-SysErr-notdir` &middot; `nonempty`

For `OS`, in [tests/basis/os.process\_os.sml](../../../../tests/basis/os.process_os.sml): `*` &middot; `nonempty-*` &middot; `same-error-same-message` &middot; `is-Posix.Error.errorMsg`

</details>

### <a name="val-errorname"></a>`errorName`

```sml
val errorName : syserror -> string
```

`errorName e` is a short name for `e`, meant for a program.

> **Implementation** `OS.errorName/posix-names`. The names are those of
> [`Posix.Error`](../sig/POSIX.md#str-error), lower case and without the `E`: `"noent"` rather than
> `"ENOENT"`. An error that POSIX has no name for is called `error` and
> its number, `"error9999"`, which [`syserror`](#val-syserror) reads back.

**Example** `Option.map errorName (syserror "error9999") = SOME "error9999"`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; OS.errorName gives the C name ("ENOENT") and Posix.Error.errorName the POSIX one ("noent") of the same syserror (the types are identical), where each is to be "a unique name used for the syserror value"; OS.syserror "noent" is NONE

</details>

<details><summary>Tests (7)</summary>

For `OS`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `syserror-inverts` &middot; `unique` &middot; `stable`

For `OS`, in [tests/basis/os.process\_os.sml](../../../../tests/basis/os.process_os.sml): `same-condition` &middot; `different-errors` &middot; `nonempty` &middot; `is-Posix.Error.errorName`

</details>

### <a name="val-syserror"></a>`syserror`

```sml
val syserror : string -> syserror option
```

`syserror s` is `SOME` of the condition that [`errorName`](#val-errorname) calls `s`, or `NONE` when there is none.

> **Reading** `OS.syserror/one-name-one-condition`. "A unique name" is read
> as: one condition gives one error and one name, whichever function met
> it, and different conditions have different names, so [`syserror`](#val-syserror) and
> [`errorName`](#val-errorname) invert each other.

<details><summary>Tests (7)</summary>

For `OS`, in [tests/basis/os.process.sml](../../../../tests/basis/os.process.sml): `inverts-errorName-notdir` &middot; `unknown-name` &middot; `empty-name`

For `OS`, in [tests/basis/os.process\_os.sml](../../../../tests/basis/os.process_os.sml): `errorName-*` &middot; `same-condition` &middot; `not-a-name` &middot; `Posix-errors`

</details>

## See also

[`OS_FILE_SYS`](../sig/OS_FILE_SYS.md), [`OS_PATH`](../sig/OS_PATH.md), [`OS_PROCESS`](../sig/OS_PROCESS.md), [`OS_IO`](../sig/OS_IO.md), [`POSIX`](../sig/POSIX.md)

---

<sub>Generated by runedoc from lib/basis/sig\_os.sml; do not edit.</sub>
