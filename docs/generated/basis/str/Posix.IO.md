# structure Posix.IO

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Posix.IO**

|  |  |
| --- | --- |
| Signature | [`POSIX_IO`](../sig/POSIX_IO.md) |
| Status | optional |
| Members | 30 |
| Tests | 61 checks |
| Source | [lib/basis/posix\_io.sml](../../../../lib/basis/posix_io.sml) |

## Synopsis

```sml
structure Posix.IO : POSIX_IO
```

Posix.IO: reading and writing by descriptor.

## Members

What each means is on [`POSIX_IO`](../sig/POSIX_IO.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`file_desc`](../sig/POSIX_IO.md#type-file_desc) | *a type of its own* |
| datatype | [`lock_type`](../sig/POSIX_IO.md#type-lock_type) | `F_RDLCK` &#124; `F_WRLCK` &#124; `F_UNLCK` |
| datatype | [`open_mode`](../sig/POSIX_IO.md#type-open_mode) | `O_RDONLY` &#124; `O_WRONLY` &#124; `O_RDWR` |
| type | [`pid`](../sig/POSIX_IO.md#type-pid) | *a type of its own* |
| datatype | [`whence`](../sig/POSIX_IO.md#type-whence) | `SEEK_SET` &#124; `SEEK_CUR` &#124; `SEEK_END` |
| val | [`close`](../sig/POSIX_IO.md#val-close) | `file_desc -> unit` |
| val | [`dup`](../sig/POSIX_IO.md#val-dup) | `file_desc -> file_desc` |
| val | [`dup2`](../sig/POSIX_IO.md#val-dup2) | `{new : file_desc, old : file_desc} -> unit` |
| val | [`dupfd`](../sig/POSIX_IO.md#val-dupfd) | `{base : file_desc, old : file_desc} -> file_desc` |
| val | [`fsync`](../sig/POSIX_IO.md#val-fsync) | `file_desc -> unit` |
| val | [`getfd`](../sig/POSIX_IO.md#val-getfd) | `file_desc -> FD.flags` |
| val | [`getfl`](../sig/POSIX_IO.md#val-getfl) | `file_desc -> O.flags * open_mode` |
| val | [`getlk`](../sig/POSIX_IO.md#val-getlk) | `file_desc * FLock.flock -> FLock.flock` |
| val | [`lseek`](../sig/POSIX_IO.md#val-lseek) | `file_desc * int * whence -> int` |
| val | [`mkBinReader`](../sig/POSIX_IO.md#val-mkbinreader) | `{fd : file_desc, initBlkMode : bool, name : string} -> BinPrimIO.reader` |
| val | [`mkBinWriter`](../sig/POSIX_IO.md#val-mkbinwriter) | `{appendMode : bool, chunkSize : int, fd : file_desc, initBlkMode : bool, name : string} -> BinPrimIO.writer` |
| val | [`mkTextReader`](../sig/POSIX_IO.md#val-mktextreader) | `{fd : file_desc, initBlkMode : bool, name : string} -> TextPrimIO.reader` |
| val | [`mkTextWriter`](../sig/POSIX_IO.md#val-mktextwriter) | `{appendMode : bool, chunkSize : int, fd : file_desc, initBlkMode : bool, name : string} -> TextPrimIO.writer` |
| val | [`pipe`](../sig/POSIX_IO.md#val-pipe) | `unit -> {infd : file_desc, outfd : file_desc}` |
| val | [`readArr`](../sig/POSIX_IO.md#val-readarr) | `file_desc * Word8ArraySlice.slice -> int` |
| val | [`readVec`](../sig/POSIX_IO.md#val-readvec) | `file_desc * int -> BinIO.vector` |
| val | [`setfd`](../sig/POSIX_IO.md#val-setfd) | `file_desc * FD.flags -> unit` |
| val | [`setfl`](../sig/POSIX_IO.md#val-setfl) | `file_desc * O.flags -> unit` |
| val | [`setlk`](../sig/POSIX_IO.md#val-setlk) | `file_desc * FLock.flock -> FLock.flock` |
| val | [`setlkw`](../sig/POSIX_IO.md#val-setlkw) | `file_desc * FLock.flock -> FLock.flock` |
| val | [`writeArr`](../sig/POSIX_IO.md#val-writearr) | `file_desc * Word8ArraySlice.slice -> int` |
| val | [`writeVec`](../sig/POSIX_IO.md#val-writevec) | `file_desc * Word8VectorSlice.slice -> int` |
| structure | [`FD`](../str/Posix.IO.FD.md) | [`BIT_FLAGS`](../sig/BIT_FLAGS.md) |
| structure | [`FLock`](../str/Posix.IO.FLock.md) |  |
| structure | [`O`](../str/Posix.IO.O.md) | [`BIT_FLAGS`](../sig/BIT_FLAGS.md) |

## Notes

### 

> **Reading** `Posix.IO/what-comes-from-posix`. Two things the page does not
> state come from POSIX itself: a descriptor that has just been made has
> [`FD.cloexec`](../sig/POSIX_IO.md#val-fd.cloexec) clear, and a process's own lock never blocks it, so [`getlk`](../sig/POSIX_IO.md#val-getlk)
> reports [`F_UNLCK`](../sig/POSIX_IO.md#con-f_unlck) for it.

### dup

> **Reading** `Posix.IO.dup/lowest-available`. "The lowest one available" is
> read strictly: closing a descriptor that was just opened and then
> calling [`dup`](../sig/POSIX_IO.md#val-dup) gives that same number back.

### getlk

> **Reading** `Posix.IO.getlk/F_UNLCK-means-free`. When nothing blocks the
> described lock, POSIX reports that as an answer of kind [`F_UNLCK`](../sig/POSIX_IO.md#con-f_unlck); and
> since a process's own locks never block it, its own lock is reported
> that way too.

### mkBinReader

> **Implementation** `Posix.IO.mkBinReader/positions`. Only a regular file
> has positions, so `getPos`, `setPos`, `endPos` and `verifyPos` are
> `NONE` for a pipe, a socket or a terminal.

<details><summary>Other implementations (3)</summary>

- **SML/NJ** &mdash; getfl returns no status flags and O\_RDONLY whatever the descriptor
- **SML/NJ (32-bit)** &mdash; lseek with a negative offset from the current position or the end gives a position of its own (2^30 + the offset), not the one it moved to
- **SML/NJ** &mdash; getfl returns no status flags and O\_RDONLY whatever the descriptor, so that what setfl sets cannot be read back (the effect of setfl (fd, O.append) is seen)

</details>

---

<sub>Generated by runedoc from lib/basis/posix\_io.sml; do not edit.</sub>
