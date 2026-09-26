# structure Posix.Error

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Posix.Error**

|  |  |
| --- | --- |
| Signature | [`POSIX_ERROR`](../sig/POSIX_ERROR.md) |
| Status | optional |
| Members | 49 |
| Tests | 35 checks |
| Source | [lib/basis/posix\_error.sml](../../../../lib/basis/posix_error.sml) |

## Synopsis

```sml
structure Posix.Error : POSIX_ERROR
```

Posix.Error: the errors the system reports. A syserror is an errno value,
the same one OS.SysErr carries.

## Members

What each means is on [`POSIX_ERROR`](../sig/POSIX_ERROR.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`syserror`](../sig/POSIX_ERROR.md#val-syserror) | *a type of its own* |
| val | [`acces`](../sig/POSIX_ERROR.md#val-acces) | `syserror` |
| val | [`again`](../sig/POSIX_ERROR.md#val-again) | `syserror` |
| val | [`badf`](../sig/POSIX_ERROR.md#val-badf) | `syserror` |
| val | [`badmsg`](../sig/POSIX_ERROR.md#val-badmsg) | `syserror` |
| val | [`busy`](../sig/POSIX_ERROR.md#val-busy) | `syserror` |
| val | [`canceled`](../sig/POSIX_ERROR.md#val-canceled) | `syserror` |
| val | [`child`](../sig/POSIX_ERROR.md#val-child) | `syserror` |
| val | [`deadlk`](../sig/POSIX_ERROR.md#val-deadlk) | `syserror` |
| val | [`dom`](../sig/POSIX_ERROR.md#val-dom) | `syserror` |
| val | [`errorMsg`](../sig/POSIX_ERROR.md#val-errormsg) | `syserror -> string` |
| val | [`errorName`](../sig/POSIX_ERROR.md#val-errorname) | `syserror -> string` |
| val | [`exist`](../sig/POSIX_ERROR.md#val-exist) | `syserror` |
| val | [`fault`](../sig/POSIX_ERROR.md#val-fault) | `syserror` |
| val | [`fbig`](../sig/POSIX_ERROR.md#val-fbig) | `syserror` |
| val | [`fromWord`](../sig/POSIX_ERROR.md#val-fromword) | `word -> syserror` |
| val | [`inprogress`](../sig/POSIX_ERROR.md#val-inprogress) | `syserror` |
| val | [`intr`](../sig/POSIX_ERROR.md#val-intr) | `syserror` |
| val | [`inval`](../sig/POSIX_ERROR.md#val-inval) | `syserror` |
| val | [`io`](../sig/POSIX_ERROR.md#val-io) | `syserror` |
| val | [`isdir`](../sig/POSIX_ERROR.md#val-isdir) | `syserror` |
| val | [`loop`](../sig/POSIX_ERROR.md#val-loop) | `syserror` |
| val | [`mfile`](../sig/POSIX_ERROR.md#val-mfile) | `syserror` |
| val | [`mlink`](../sig/POSIX_ERROR.md#val-mlink) | `syserror` |
| val | [`msgsize`](../sig/POSIX_ERROR.md#val-msgsize) | `syserror` |
| val | [`nametoolong`](../sig/POSIX_ERROR.md#val-nametoolong) | `syserror` |
| val | [`nfile`](../sig/POSIX_ERROR.md#val-nfile) | `syserror` |
| val | [`nodev`](../sig/POSIX_ERROR.md#val-nodev) | `syserror` |
| val | [`noent`](../sig/POSIX_ERROR.md#val-noent) | `syserror` |
| val | [`noexec`](../sig/POSIX_ERROR.md#val-noexec) | `syserror` |
| val | [`nolck`](../sig/POSIX_ERROR.md#val-nolck) | `syserror` |
| val | [`nomem`](../sig/POSIX_ERROR.md#val-nomem) | `syserror` |
| val | [`nospc`](../sig/POSIX_ERROR.md#val-nospc) | `syserror` |
| val | [`nosys`](../sig/POSIX_ERROR.md#val-nosys) | `syserror` |
| val | [`notdir`](../sig/POSIX_ERROR.md#val-notdir) | `syserror` |
| val | [`notempty`](../sig/POSIX_ERROR.md#val-notempty) | `syserror` |
| val | [`notsup`](../sig/POSIX_ERROR.md#val-notsup) | `syserror` |
| val | [`notty`](../sig/POSIX_ERROR.md#val-notty) | `syserror` |
| val | [`nxio`](../sig/POSIX_ERROR.md#val-nxio) | `syserror` |
| val | [`perm`](../sig/POSIX_ERROR.md#val-perm) | `syserror` |
| val | [`pipe`](../sig/POSIX_ERROR.md#val-pipe) | `syserror` |
| val | [`range`](../sig/POSIX_ERROR.md#val-range) | `syserror` |
| val | [`rofs`](../sig/POSIX_ERROR.md#val-rofs) | `syserror` |
| val | [`spipe`](../sig/POSIX_ERROR.md#val-spipe) | `syserror` |
| val | [`srch`](../sig/POSIX_ERROR.md#val-srch) | `syserror` |
| val | [`syserror`](../sig/POSIX_ERROR.md#val-syserror) | `string -> syserror option` |
| val | [`toWord`](../sig/POSIX_ERROR.md#val-toword) | `syserror -> word` |
| val | [`toobig`](../sig/POSIX_ERROR.md#val-toobig) | `syserror` |
| val | [`xdev`](../sig/POSIX_ERROR.md#val-xdev) | `syserror` |

## Notes

### 

> **Reading** `Posix.Error/which-error-is-posix's`. Which condition a failing
> call reports is prescribed by POSIX and not by this library; where POSIX
> allows two, the suite accepts either.

### acces

> **Implementation** `Posix.Error.acces/not-for-the-superuser`. Permission
> bits do not stop a privileged process, so the suite's checks of this and
> of [`perm`](../sig/POSIX_ERROR.md#val-perm) hold for an ordinary user and pass trivially as root.

### errorName

> **Implementation** `Posix.Error.errorName/the-posix-names`. For the
> conditions POSIX names it is the name below -- `"noent"` for [`noent`](../sig/POSIX_ERROR.md#val-noent) \--
> and for the others it is the name [`OS.errorName`](../sig/OS.md#val-errorname) invents.

### inval

> **Implementation** `Posix.Error.inval/rename-into-itself`. Renaming a
> directory into itself is taken to report this condition.

### pipe

> **Reading** `Posix.Error.pipe/or-the-signal`. Writing to such a pipe either
> ends the writer with [`Posix.Signal.pipe`](../sig/POSIX_SIGNAL.md#val-pipe) or, when that signal is ignored
> or caught, fails with this condition; the suite accepts both.

<details><summary>Other implementations (3)</summary>

- **Poly/ML** &mdash; Posix.IO.close of a descriptor that is already closed raises no exception
- **SML/NJ** &mdash; ttyname of a descriptor that is not a terminal raises SysErr with NONE, not SOME notty
- **SML/NJ 110.99.9** &mdash; Posix.IO.lseek on a pipe raises another exception than SysErr (spipe); outside the suite the runtime stops with "bogus overflow fault"

</details>

---

<sub>Generated by runedoc from lib/basis/posix\_error.sml; do not edit.</sub>
