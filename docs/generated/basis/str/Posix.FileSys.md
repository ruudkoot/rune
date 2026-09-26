# structure Posix.FileSys

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Posix.FileSys**

|  |  |
| --- | --- |
| Signature | [`POSIX_FILE_SYS`](../sig/POSIX_FILE_SYS.md) |
| Status | optional |
| Members | 52 |
| Tests | 130 checks |
| Source | [lib/basis/posix\_filesys.sml](../../../../lib/basis/posix_filesys.sml) |

## Synopsis

```sml
structure Posix.FileSys : POSIX_FILE_SYS
```

Posix.FileSys: files by their descriptors, and what stat reports.

## Members

What each means is on [`POSIX_FILE_SYS`](../sig/POSIX_FILE_SYS.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| datatype | [`access_mode`](../sig/POSIX_FILE_SYS.md#type-access_mode) | `A_READ` &#124; `A_WRITE` &#124; `A_EXEC` |
| type | [`dev`](../sig/POSIX_FILE_SYS.md#type-dev) | *a type of its own* |
| type | [`dirstream`](../sig/POSIX_FILE_SYS.md#type-dirstream) | *a type of its own* |
| type | [`file_desc`](../sig/POSIX_FILE_SYS.md#type-file_desc) | *a type of its own* |
| type | [`gid`](../sig/POSIX_FILE_SYS.md#type-gid) | *a type of its own* |
| type | [`ino`](../sig/POSIX_FILE_SYS.md#type-ino) | *a type of its own* |
| datatype | [`open_mode`](../sig/POSIX_FILE_SYS.md#type-open_mode) | `O_RDONLY` &#124; `O_WRONLY` &#124; `O_RDWR` |
| type | [`uid`](../sig/POSIX_FILE_SYS.md#type-uid) | *a type of its own* |
| val | [`access`](../sig/POSIX_FILE_SYS.md#val-access) | `string * access_mode list -> bool` |
| val | [`chdir`](../sig/POSIX_FILE_SYS.md#val-chdir) | `string -> unit` |
| val | [`chmod`](../sig/POSIX_FILE_SYS.md#val-chmod) | `string * S.mode -> unit` |
| val | [`chown`](../sig/POSIX_FILE_SYS.md#val-chown) | `string * uid * gid -> unit` |
| val | [`closedir`](../sig/POSIX_FILE_SYS.md#val-closedir) | `dirstream -> unit` |
| val | [`creat`](../sig/POSIX_FILE_SYS.md#val-creat) | `string * S.mode -> file_desc` |
| val | [`createf`](../sig/POSIX_FILE_SYS.md#val-createf) | `string * open_mode * O.flags * S.mode -> file_desc` |
| val | [`devToWord`](../sig/POSIX_FILE_SYS.md#val-devtoword) | `dev -> word` |
| val | [`fchmod`](../sig/POSIX_FILE_SYS.md#val-fchmod) | `file_desc * S.mode -> unit` |
| val | [`fchown`](../sig/POSIX_FILE_SYS.md#val-fchown) | `file_desc * uid * gid -> unit` |
| val | [`fdToIOD`](../sig/POSIX_FILE_SYS.md#val-fdtoiod) | `file_desc -> OS.IO.iodesc` |
| val | [`fdToWord`](../sig/POSIX_FILE_SYS.md#val-fdtoword) | `file_desc -> word` |
| val | [`fpathconf`](../sig/POSIX_FILE_SYS.md#val-fpathconf) | `file_desc * string -> word option` |
| val | [`fstat`](../sig/POSIX_FILE_SYS.md#val-fstat) | `file_desc -> ST.stat` |
| val | [`ftruncate`](../sig/POSIX_FILE_SYS.md#val-ftruncate) | `file_desc * int -> unit` |
| val | [`getcwd`](../sig/POSIX_FILE_SYS.md#val-getcwd) | `unit -> string` |
| val | [`inoToWord`](../sig/POSIX_FILE_SYS.md#val-inotoword) | `ino -> word` |
| val | [`iodToFD`](../sig/POSIX_FILE_SYS.md#val-iodtofd) | `OS.IO.iodesc -> file_desc option` |
| val | [`link`](../sig/POSIX_FILE_SYS.md#val-link) | `{new : string, old : string} -> unit` |
| val | [`lstat`](../sig/POSIX_FILE_SYS.md#val-lstat) | `string -> ST.stat` |
| val | [`mkdir`](../sig/POSIX_FILE_SYS.md#val-mkdir) | `string * S.mode -> unit` |
| val | [`mkfifo`](../sig/POSIX_FILE_SYS.md#val-mkfifo) | `string * S.mode -> unit` |
| val | [`opendir`](../sig/POSIX_FILE_SYS.md#val-opendir) | `string -> dirstream` |
| val | [`openf`](../sig/POSIX_FILE_SYS.md#val-openf) | `string * open_mode * O.flags -> file_desc` |
| val | [`pathconf`](../sig/POSIX_FILE_SYS.md#val-pathconf) | `string * string -> word option` |
| val | [`readdir`](../sig/POSIX_FILE_SYS.md#val-readdir) | `dirstream -> string option` |
| val | [`readlink`](../sig/POSIX_FILE_SYS.md#val-readlink) | `string -> string` |
| val | [`rename`](../sig/POSIX_FILE_SYS.md#val-rename) | `{new : string, old : string} -> unit` |
| val | [`rewinddir`](../sig/POSIX_FILE_SYS.md#val-rewinddir) | `dirstream -> unit` |
| val | [`rmdir`](../sig/POSIX_FILE_SYS.md#val-rmdir) | `string -> unit` |
| val | [`stat`](../sig/POSIX_FILE_SYS.md#val-stat) | `string -> ST.stat` |
| val | [`stderr`](../sig/POSIX_FILE_SYS.md#val-stderr) | `file_desc` |
| val | [`stdin`](../sig/POSIX_FILE_SYS.md#val-stdin) | `file_desc` |
| val | [`stdout`](../sig/POSIX_FILE_SYS.md#val-stdout) | `file_desc` |
| val | [`symlink`](../sig/POSIX_FILE_SYS.md#val-symlink) | `{new : string, old : string} -> unit` |
| val | [`umask`](../sig/POSIX_FILE_SYS.md#val-umask) | `S.mode -> S.mode` |
| val | [`unlink`](../sig/POSIX_FILE_SYS.md#val-unlink) | `string -> unit` |
| val | [`utime`](../sig/POSIX_FILE_SYS.md#val-utime) | `string * {actime : Time.time, modtime : Time.time} option -> unit` |
| val | [`wordToDev`](../sig/POSIX_FILE_SYS.md#val-wordtodev) | `word -> dev` |
| val | [`wordToFD`](../sig/POSIX_FILE_SYS.md#val-wordtofd) | `word -> file_desc` |
| val | [`wordToIno`](../sig/POSIX_FILE_SYS.md#val-wordtoino) | `word -> ino` |
| structure | [`O`](../str/Posix.FileSys.O.md) | [`BIT_FLAGS`](../sig/BIT_FLAGS.md) |
| structure | [`S`](../str/Posix.FileSys.S.md) | [`BIT_FLAGS`](../sig/BIT_FLAGS.md) |
| structure | [`ST`](../str/Posix.FileSys.ST.md) |  |

## Notes

### 

> **Reading** `Posix.FileSys/empty-path-raises`. An empty path raises
> [`OS.SysErr`](../sig/OS.md#exn-syserr) with `noent`, as the system would, although inside the library
> the empty string means "use the descriptor instead".

### chown

> **Implementation** `Posix.FileSys.chown/only-what-is-allowed`. An
> unprivileged process may not give a file away, so the suite only checks
> setting the owner and group a file already has.

### createf

> **Reading** `Posix.FileSys.createf/existing-file-is-opened`. The page
> speaks of the permissions only for a file that has to be made, so a file
> that is there already is opened as it stands: neither its contents nor
> its permissions are touched, unless [`O.trunc`](../sig/POSIX_FILE_SYS.md#val-o.trunc) is given.

### mkdir

> **Implementation** `Posix.FileSys.mkdir/shares-OS.FileSys`. [`rmdir`](../sig/POSIX_FILE_SYS.md#val-rmdir), [`chdir`](../sig/POSIX_FILE_SYS.md#val-chdir),
> [`getcwd`](../sig/POSIX_FILE_SYS.md#val-getcwd), [`unlink`](../sig/POSIX_FILE_SYS.md#val-unlink), [`rename`](../sig/POSIX_FILE_SYS.md#val-rename), [`readlink`](../sig/POSIX_FILE_SYS.md#val-readlink), the directory streams and
> [`access`](../sig/POSIX_FILE_SYS.md#val-access) are the functions of [`OS.FileSys`](../sig/OS.md#str-filesys) under the names of POSIX, and
> [`mkdir`](../sig/POSIX_FILE_SYS.md#val-mkdir) differs from [`OS.FileSys.mkDir`](../sig/OS_FILE_SYS.md#val-mkdir) in the mode only.

### pathconf

> **Implementation** `Posix.FileSys.pathconf/what-a-check-can-assume`. The
> suite asks that `NAME_MAX` be bounded and lie between 13 and 255, and
> allows `PATH_MAX` and `LINK_MAX` to be unbounded, `PATH_MAX` being at
> most 65535 when it is not.

### stdin

> **Implementation** `Posix.FileSys.stdin/is-0`. The three standard
> descriptors are the words 0, 1 and 2, which POSIX fixes and the page
> does not state.

### umask

> **Reading** `Posix.FileSys.umask/not-for-chmod`. The mask applies to files
> that are created; [`chmod`](../sig/POSIX_FILE_SYS.md#val-chmod) sets what it is given, mask or no mask.

<details><summary>Other implementations (2)</summary>

- **Poly/ML 5.9.2** &mdash; wordToFD 0w0 is not equal (=) to stdin: equality of file\_desc is that of the object
- **Poly/ML** &mdash; wordToFD makes a new file\_desc that is not equal (=) to the file\_desc with the same number: equality of file\_desc is that of the object

</details>

---

<sub>Generated by runedoc from lib/basis/posix\_filesys.sml; do not edit.</sub>
