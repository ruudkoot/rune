# structure Posix.Error

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Posix.Error**

|  |  |
| --- | --- |
| Signature | [`POSIX_ERROR`](../sig/POSIX_ERROR.md) |
| Status | optional |
| Members | 49 |
| Tests | 77 checks |
| Source | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

## Synopsis

```sml
structure Posix.Error : POSIX_ERROR
```

Posix.Error: the conditions a failing call reports, with their names
and numbers.

## Members

What each means is on [`POSIX_ERROR`](../sig/POSIX_ERROR.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`syserror`](../sig/POSIX_ERROR.md#type-syserror) | `RuneError.syserror` |
| val | [`acces`](../sig/POSIX_ERROR.md#val-acces) | `RuneError.syserror` |
| val | [`again`](../sig/POSIX_ERROR.md#val-again) | `RuneError.syserror` |
| val | [`badf`](../sig/POSIX_ERROR.md#val-badf) | `RuneError.syserror` |
| val | [`badmsg`](../sig/POSIX_ERROR.md#val-badmsg) | `RuneError.syserror` |
| val | [`busy`](../sig/POSIX_ERROR.md#val-busy) | `RuneError.syserror` |
| val | [`canceled`](../sig/POSIX_ERROR.md#val-canceled) | `RuneError.syserror` |
| val | [`child`](../sig/POSIX_ERROR.md#val-child) | `RuneError.syserror` |
| val | [`deadlk`](../sig/POSIX_ERROR.md#val-deadlk) | `RuneError.syserror` |
| val | [`dom`](../sig/POSIX_ERROR.md#val-dom) | `RuneError.syserror` |
| val | [`errorMsg`](../sig/POSIX_ERROR.md#val-errormsg) | `RuneError.syserror -> string` |
| val | [`errorName`](../sig/POSIX_ERROR.md#val-errorname) | `RuneError.syserror -> string` |
| val | [`exist`](../sig/POSIX_ERROR.md#val-exist) | `RuneError.syserror` |
| val | [`fault`](../sig/POSIX_ERROR.md#val-fault) | `RuneError.syserror` |
| val | [`fbig`](../sig/POSIX_ERROR.md#val-fbig) | `RuneError.syserror` |
| val | [`fromWord`](../sig/POSIX_ERROR.md#val-fromword) | `word -> RuneError.syserror` |
| val | [`inprogress`](../sig/POSIX_ERROR.md#val-inprogress) | `RuneError.syserror` |
| val | [`intr`](../sig/POSIX_ERROR.md#val-intr) | `RuneError.syserror` |
| val | [`inval`](../sig/POSIX_ERROR.md#val-inval) | `RuneError.syserror` |
| val | [`io`](../sig/POSIX_ERROR.md#val-io) | `RuneError.syserror` |
| val | [`isdir`](../sig/POSIX_ERROR.md#val-isdir) | `RuneError.syserror` |
| val | [`loop`](../sig/POSIX_ERROR.md#val-loop) | `RuneError.syserror` |
| val | [`mfile`](../sig/POSIX_ERROR.md#val-mfile) | `RuneError.syserror` |
| val | [`mlink`](../sig/POSIX_ERROR.md#val-mlink) | `RuneError.syserror` |
| val | [`msgsize`](../sig/POSIX_ERROR.md#val-msgsize) | `RuneError.syserror` |
| val | [`nametoolong`](../sig/POSIX_ERROR.md#val-nametoolong) | `RuneError.syserror` |
| val | [`nfile`](../sig/POSIX_ERROR.md#val-nfile) | `RuneError.syserror` |
| val | [`nodev`](../sig/POSIX_ERROR.md#val-nodev) | `RuneError.syserror` |
| val | [`noent`](../sig/POSIX_ERROR.md#val-noent) | `RuneError.syserror` |
| val | [`noexec`](../sig/POSIX_ERROR.md#val-noexec) | `RuneError.syserror` |
| val | [`nolck`](../sig/POSIX_ERROR.md#val-nolck) | `RuneError.syserror` |
| val | [`nomem`](../sig/POSIX_ERROR.md#val-nomem) | `RuneError.syserror` |
| val | [`nospc`](../sig/POSIX_ERROR.md#val-nospc) | `RuneError.syserror` |
| val | [`nosys`](../sig/POSIX_ERROR.md#val-nosys) | `RuneError.syserror` |
| val | [`notdir`](../sig/POSIX_ERROR.md#val-notdir) | `RuneError.syserror` |
| val | [`notempty`](../sig/POSIX_ERROR.md#val-notempty) | `RuneError.syserror` |
| val | [`notsup`](../sig/POSIX_ERROR.md#val-notsup) | `RuneError.syserror` |
| val | [`notty`](../sig/POSIX_ERROR.md#val-notty) | `RuneError.syserror` |
| val | [`nxio`](../sig/POSIX_ERROR.md#val-nxio) | `RuneError.syserror` |
| val | [`perm`](../sig/POSIX_ERROR.md#val-perm) | `RuneError.syserror` |
| val | [`pipe`](../sig/POSIX_ERROR.md#val-pipe) | `RuneError.syserror` |
| val | [`range`](../sig/POSIX_ERROR.md#val-range) | `RuneError.syserror` |
| val | [`rofs`](../sig/POSIX_ERROR.md#val-rofs) | `RuneError.syserror` |
| val | [`spipe`](../sig/POSIX_ERROR.md#val-spipe) | `RuneError.syserror` |
| val | [`srch`](../sig/POSIX_ERROR.md#val-srch) | `RuneError.syserror` |
| val | [`syserror`](../sig/POSIX_ERROR.md#val-syserror) | `string -> RuneError.syserror option` |
| val | [`toWord`](../sig/POSIX_ERROR.md#val-toword) | `RuneError.syserror -> word` |
| val | [`toobig`](../sig/POSIX_ERROR.md#val-toobig) | `RuneError.syserror` |
| val | [`xdev`](../sig/POSIX_ERROR.md#val-xdev) | `RuneError.syserror` |

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

<details><summary>Other implementations (8)</summary>

- **MLKit** &mdash; errorName again is "wouldblock" and errorName notsup is "opnotsupp" ("errorName badmsg = "badmsg""): the runtime's table from numbers to names has both names of EAGAIN = EWOULDBLOCK and ENOTSUP = EOPNOTSUPP, and its binary search finds the other one
- **Poly/ML** &mdash; Posix.IO.close of a descriptor that is already closed raises no exception
- **MLKit** &mdash; Posix.IO.close never raises OS.SysErr: the library calls C's close, which returns an int, by auto-conversion, which reads the result as a long, so -1 comes back as 4294967295
- **MLKit** &mdash; the string of SysErr (s, SOME e) is not errorMsg e ("then we have errorMsg e = s"): it names the operation and the file first, "remove failed on \`f': No such file or directory"
- **SML/NJ** &mdash; ttyname of a descriptor that is not a terminal raises SysErr with NONE, not SOME notty
- **MLKit** &mdash; compiler bug: the X64 backend compares the pointer of \_\_is\_null with the address of a boxed 0, so the library never sees that a C function returned NULL: ttyname of a descriptor that is not a terminal returns NULL as its string instead of raising OS.SysErr
- **SML/NJ 110.99.9** &mdash; Posix.IO.lseek on a pipe raises another exception than SysErr (spipe); outside the suite the runtime stops with "bogus overflow fault"
- **MLKit** &mdash; lseek of a pipe returns 2147483647 instead of raising OS.SysErr: the runtime's sml\_lseek takes and returns C ints, so -1 comes back as 2^31-1 (and an offset of 2^30 or more is cut to 32 bits)

</details>

---

<sub>Generated by runedoc from lib/basis/posix.sml; do not edit.</sub>
