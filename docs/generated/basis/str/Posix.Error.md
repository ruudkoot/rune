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
| type | [`syserror`](../sig/POSIX_ERROR.md#type-syserror) | `OS.syserror` |
| val | [`acces`](../sig/POSIX_ERROR.md#val-acces) | `OS.syserror` |
| val | [`again`](../sig/POSIX_ERROR.md#val-again) | `OS.syserror` |
| val | [`badf`](../sig/POSIX_ERROR.md#val-badf) | `OS.syserror` |
| val | [`badmsg`](../sig/POSIX_ERROR.md#val-badmsg) | `OS.syserror` |
| val | [`busy`](../sig/POSIX_ERROR.md#val-busy) | `OS.syserror` |
| val | [`canceled`](../sig/POSIX_ERROR.md#val-canceled) | `OS.syserror` |
| val | [`child`](../sig/POSIX_ERROR.md#val-child) | `OS.syserror` |
| val | [`deadlk`](../sig/POSIX_ERROR.md#val-deadlk) | `OS.syserror` |
| val | [`dom`](../sig/POSIX_ERROR.md#val-dom) | `OS.syserror` |
| val | [`errorMsg`](../sig/POSIX_ERROR.md#val-errormsg) | `OS.syserror -> string` |
| val | [`errorName`](../sig/POSIX_ERROR.md#val-errorname) | `OS.syserror -> string` |
| val | [`exist`](../sig/POSIX_ERROR.md#val-exist) | `OS.syserror` |
| val | [`fault`](../sig/POSIX_ERROR.md#val-fault) | `OS.syserror` |
| val | [`fbig`](../sig/POSIX_ERROR.md#val-fbig) | `OS.syserror` |
| val | [`fromWord`](../sig/POSIX_ERROR.md#val-fromword) | `word -> OS.syserror` |
| val | [`inprogress`](../sig/POSIX_ERROR.md#val-inprogress) | `OS.syserror` |
| val | [`intr`](../sig/POSIX_ERROR.md#val-intr) | `OS.syserror` |
| val | [`inval`](../sig/POSIX_ERROR.md#val-inval) | `OS.syserror` |
| val | [`io`](../sig/POSIX_ERROR.md#val-io) | `OS.syserror` |
| val | [`isdir`](../sig/POSIX_ERROR.md#val-isdir) | `OS.syserror` |
| val | [`loop`](../sig/POSIX_ERROR.md#val-loop) | `OS.syserror` |
| val | [`mfile`](../sig/POSIX_ERROR.md#val-mfile) | `OS.syserror` |
| val | [`mlink`](../sig/POSIX_ERROR.md#val-mlink) | `OS.syserror` |
| val | [`msgsize`](../sig/POSIX_ERROR.md#val-msgsize) | `OS.syserror` |
| val | [`nametoolong`](../sig/POSIX_ERROR.md#val-nametoolong) | `OS.syserror` |
| val | [`nfile`](../sig/POSIX_ERROR.md#val-nfile) | `OS.syserror` |
| val | [`nodev`](../sig/POSIX_ERROR.md#val-nodev) | `OS.syserror` |
| val | [`noent`](../sig/POSIX_ERROR.md#val-noent) | `OS.syserror` |
| val | [`noexec`](../sig/POSIX_ERROR.md#val-noexec) | `OS.syserror` |
| val | [`nolck`](../sig/POSIX_ERROR.md#val-nolck) | `OS.syserror` |
| val | [`nomem`](../sig/POSIX_ERROR.md#val-nomem) | `OS.syserror` |
| val | [`nospc`](../sig/POSIX_ERROR.md#val-nospc) | `OS.syserror` |
| val | [`nosys`](../sig/POSIX_ERROR.md#val-nosys) | `OS.syserror` |
| val | [`notdir`](../sig/POSIX_ERROR.md#val-notdir) | `OS.syserror` |
| val | [`notempty`](../sig/POSIX_ERROR.md#val-notempty) | `OS.syserror` |
| val | [`notsup`](../sig/POSIX_ERROR.md#val-notsup) | `OS.syserror` |
| val | [`notty`](../sig/POSIX_ERROR.md#val-notty) | `OS.syserror` |
| val | [`nxio`](../sig/POSIX_ERROR.md#val-nxio) | `OS.syserror` |
| val | [`perm`](../sig/POSIX_ERROR.md#val-perm) | `OS.syserror` |
| val | [`pipe`](../sig/POSIX_ERROR.md#val-pipe) | `OS.syserror` |
| val | [`range`](../sig/POSIX_ERROR.md#val-range) | `OS.syserror` |
| val | [`rofs`](../sig/POSIX_ERROR.md#val-rofs) | `OS.syserror` |
| val | [`spipe`](../sig/POSIX_ERROR.md#val-spipe) | `OS.syserror` |
| val | [`srch`](../sig/POSIX_ERROR.md#val-srch) | `OS.syserror` |
| val | [`syserror`](../sig/POSIX_ERROR.md#val-syserror) | `string -> OS.syserror option` |
| val | [`toWord`](../sig/POSIX_ERROR.md#val-toword) | `OS.syserror -> word` |
| val | [`toobig`](../sig/POSIX_ERROR.md#val-toobig) | `OS.syserror` |
| val | [`xdev`](../sig/POSIX_ERROR.md#val-xdev) | `OS.syserror` |

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
