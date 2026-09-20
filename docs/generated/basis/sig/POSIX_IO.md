# signature POSIX_IO

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **POSIX_IO**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 41 of 41 entries documented |
| Tests | 86 checks of 33 entries |
| Source | [lib/basis/sig\_posix\_io.sml](../../../../lib/basis/sig_posix_io.sml) |

## Synopsis

```sml
signature POSIX_IO
structure Posix.IO : POSIX_IO  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.IO` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

File descriptors: reading and writing them, duplicating them, positioning
them, locking them, and turning them into readers and writers.

A [`file_desc`](#type-file_desc) is the small number the system knows an open file by.
[`Posix.FileSys`](../sig/POSIX.md#str-filesys) opens files and gives descriptors; this signature is what
a program does with one afterwards.

[`mkBinReader`](#val-mkbinreader) and the three like it bridge to the rest of the library:
they wrap a descriptor as a [`PRIM_IO`](../sig/PRIM_IO.md) reader or writer, which
[`STREAM_IO`](../sig/STREAM_IO.md) and then [`TEXT_IO`](../sig/TEXT_IO.md) or [`BIN_IO`](../sig/BIN_IO.md) build streams on.

> **Erratum** `POSIX_IO/flexible-types`. The types are kept as the page writes
> them; the identities that [`POSIX`](../sig/POSIX.md) states in its `where type` clauses --
> [`pid`](#type-pid) is [`Posix.Process.pid`](../sig/POSIX_PROCESS.md#type-pid), [`file_desc`](#type-file_desc) is [`Posix.ProcEnv.file_desc`](../sig/POSIX_PROC_ENV.md#type-file_desc), and
> [`open_mode`](#type-open_mode) is
> [`Posix.FileSys.open_mode`](../sig/POSIX_FILE_SYS.md#type-open_mode) \-- are checked in the suite rather than written
> here.

> **Reading** `Posix.IO/what-comes-from-posix`. Two things the page does not
> state come from POSIX itself: a descriptor that has just been made has
> [`FD.cloexec`](#val-fd.cloexec) clear, and a process's own lock never blocks it, so [`getlk`](#val-getlk)
> reports [`F_UNLCK`](#con-f_unlck) for it.

## Interface

<pre>
signature POSIX_IO =
sig
  eqtype <a href="#type-file_desc">file_desc</a>

  eqtype <a href="#type-pid">pid</a>

  val <a href="#val-pipe">pipe</a> : unit -&gt; {<a href="#fld-pipe.infd">infd</a> : file_desc, <a href="#fld-pipe.outfd">outfd</a> : file_desc}

  val <a href="#val-dup">dup</a> : file_desc -&gt; file_desc

  val <a href="#val-dup2">dup2</a> : {<a href="#fld-dup2.old">old</a> : file_desc, <a href="#fld-dup2.new">new</a> : file_desc} -&gt; unit

  val <a href="#val-close">close</a> : file_desc -&gt; unit

  val <a href="#val-readvec">readVec</a> : file_desc * int -&gt; Word8Vector.vector

  val <a href="#val-readarr">readArr</a> : file_desc * Word8ArraySlice.slice -&gt; int

  val <a href="#val-writevec">writeVec</a> : file_desc * Word8VectorSlice.slice -&gt; int

  val <a href="#val-writearr">writeArr</a> : file_desc * Word8ArraySlice.slice -&gt; int

  datatype <a href="#type-whence">whence</a>
    = <a href="#con-seek_set">SEEK_SET</a>
    | <a href="#con-seek_cur">SEEK_CUR</a>
    | <a href="#con-seek_end">SEEK_END</a>

  structure <a href="#str-fd">FD</a> :
  sig
    include BIT_FLAGS

    val <a href="#val-fd.cloexec">cloexec</a> : flags
  end

  structure <a href="#str-o">O</a> :
  sig
    include BIT_FLAGS

    val <a href="#val-o.append">append</a> : flags

    val <a href="#val-o.nonblock">nonblock</a> : flags

    val <a href="#val-o.sync">sync</a> : flags
  end

  datatype <a href="#type-open_mode">open_mode</a>
    = <a href="#con-o_rdonly">O_RDONLY</a>
    | <a href="#con-o_wronly">O_WRONLY</a>
    | <a href="#con-o_rdwr">O_RDWR</a>

  val <a href="#val-dupfd">dupfd</a> : {<a href="#fld-dupfd.old">old</a> : file_desc, <a href="#fld-dupfd.base">base</a> : file_desc}
              -&gt; file_desc

  val <a href="#val-getfd">getfd</a> : file_desc -&gt; FD.flags

  val <a href="#val-setfd">setfd</a> : file_desc * FD.flags -&gt; unit

  val <a href="#val-getfl">getfl</a> : file_desc -&gt; O.flags * open_mode

  val <a href="#val-setfl">setfl</a> : file_desc * O.flags -&gt; unit

  val <a href="#val-lseek">lseek</a> : file_desc * Position.int * whence
              -&gt; Position.int

  val <a href="#val-fsync">fsync</a> : file_desc -&gt; unit

  datatype <a href="#type-lock_type">lock_type</a>
    = <a href="#con-f_rdlck">F_RDLCK</a>
    | <a href="#con-f_wrlck">F_WRLCK</a>
    | <a href="#con-f_unlck">F_UNLCK</a>

  structure <a href="#str-flock">FLock</a> :
  sig
    type <a href="#type-flock.flock">flock</a>

    val <a href="#val-flock.flock">flock</a> : {
                  <a href="#fld-flock.flock.ltype">ltype</a> : lock_type,
                  <a href="#fld-flock.flock.whence">whence</a> : whence,
                  <a href="#fld-flock.flock.start">start</a> : Position.int,
                  <a href="#fld-flock.flock.len">len</a> : Position.int,
                  <a href="#fld-flock.flock.pid">pid</a> : pid option
                } -&gt; flock

    val <a href="#val-flock.ltype">ltype</a> : flock -&gt; lock_type

    val <a href="#val-flock.whence">whence</a> : flock -&gt; whence

    val <a href="#val-flock.start">start</a> : flock -&gt; Position.int

    val <a href="#val-flock.len">len</a> : flock -&gt; Position.int

    val <a href="#val-flock.pid">pid</a> : flock -&gt; pid option
  end

  val <a href="#val-getlk">getlk</a> : file_desc * FLock.flock -&gt; FLock.flock

  val <a href="#val-setlk">setlk</a> : file_desc * FLock.flock -&gt; FLock.flock

  val <a href="#val-setlkw">setlkw</a> : file_desc * FLock.flock -&gt; FLock.flock

  val <a href="#val-mkbinreader">mkBinReader</a> : {
                      <a href="#fld-mkbinreader.fd">fd</a> : file_desc,
                      <a href="#fld-mkbinreader.name">name</a> : string,
                      <a href="#fld-mkbinreader.initblkmode">initBlkMode</a> : bool
                    } -&gt; BinPrimIO.reader

  val <a href="#val-mktextreader">mkTextReader</a> : {
                       <a href="#fld-mktextreader.fd">fd</a> : file_desc,
                       <a href="#fld-mktextreader.name">name</a> : string,
                       <a href="#fld-mktextreader.initblkmode">initBlkMode</a> : bool
                     } -&gt; TextPrimIO.reader

  val <a href="#val-mkbinwriter">mkBinWriter</a> : {
                      <a href="#fld-mkbinwriter.fd">fd</a> : file_desc,
                      <a href="#fld-mkbinwriter.name">name</a> : string,
                      <a href="#fld-mkbinwriter.appendmode">appendMode</a> : bool,
                      <a href="#fld-mkbinwriter.initblkmode">initBlkMode</a> : bool,
                      <a href="#fld-mkbinwriter.chunksize">chunkSize</a> : int
                    } -&gt; BinPrimIO.writer

  val <a href="#val-mktextwriter">mkTextWriter</a> : {
                       <a href="#fld-mktextwriter.fd">fd</a> : file_desc,
                       <a href="#fld-mktextwriter.name">name</a> : string,
                       <a href="#fld-mktextwriter.appendmode">appendMode</a> : bool,
                       <a href="#fld-mktextwriter.initblkmode">initBlkMode</a> : bool,
                       <a href="#fld-mktextwriter.chunksize">chunkSize</a> : int
                     } -&gt; TextPrimIO.writer
end
</pre>

### <a name="type-file_desc"></a>`file_desc`

```sml
eqtype file_desc
```

The type of an open file descriptor.

> **Deviation** `Posix.IO.file_desc/is-an-int`. The specification leaves the
> type abstract; in Rune it is `int`, the number the system uses, and the
> structure is not sealed.

### <a name="type-pid"></a>`pid`

```sml
eqtype pid
```

The type of the number that names a process, the one of [`Posix.Process`](../sig/POSIX.md#str-process).

### <a name="val-pipe"></a>`pipe`

```sml
val pipe : unit -> {infd : file_desc, outfd : file_desc}
```

`pipe ()` is a pair of descriptors: what is written to `outfd` can be read from `infd`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no pipe can be made.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-pipe.infd"></a>`infd` | `file_desc` |  |
| <a name="fld-pipe.outfd"></a>`outfd` | `file_desc` |  |

<details><summary>Tests (5)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `write-then-read` &middot; `distinct-ends` &middot; `end-of-stream-when-writer-closed` &middot; `read-end-cannot-write` (raises) &middot; `kind`

</details>

### <a name="val-dup"></a>`dup`

```sml
val dup : file_desc -> file_desc
```

`dup fd` is a new descriptor on the same open file as `fd`.

The two share their position, so reading through one moves the other.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open, or no descriptor is free.

> **Reading** `Posix.IO.dup/lowest-available`. "The lowest one available" is
> read strictly: closing a descriptor that was just opened and then
> calling [`dup`](#val-dup) gives that same number back.

<details><summary>Tests (4)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `same-file-pointer` &middot; `new-descriptor` &middot; `same-access-mode` (raises) &middot; `lowest-available`

</details>

### <a name="val-dup2"></a>`dup2`

```sml
val dup2 : {old : file_desc, new : file_desc} -> unit
```

`dup2 {old, new}` makes `new` a descriptor on the same open file as `old`, closing what `new` was on.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `old` is not open.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-dup2.old"></a>`old` | `file_desc` |  |
| <a name="fld-dup2.new"></a>`new` | `file_desc` |  |

<details><summary>Tests (2)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `redirects` &middot; `same-descriptor`

</details>

### <a name="val-close"></a>`close`

```sml
val close : file_desc -> unit
```

`close fd` closes `fd`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` was not open.

<details><summary>Tests (3)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `then-read` (raises) &middot; `then-write` (raises) &middot; `other-end-sees-end-of-stream`

</details>

### <a name="val-readvec"></a>`readVec`

```sml
val readVec : file_desc * int -> Word8Vector.vector
```

`readVec (fd, n)` reads at most `n` bytes from `fd` and is what it read.

A shorter vector than `n` means only that less was there; the empty
vector means the end of the file.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0`; [`OS.SysErr`](../sig/OS.md#exn-syserr) if the read fails.

<details><summary>Tests (7)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `at-most-n` &middot; `continues` &middot; `zero` &middot; `empty-file` &middot; `binary` &middot; `negative` (raises) &middot; `write-only` (raises)

</details>

### <a name="val-readarr"></a>`readArr`

```sml
val readArr : file_desc * Word8ArraySlice.slice -> int
```

`readArr (fd, sl)` reads into the stretch `sl` and is the number of bytes read, 0 at the end of the file.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the read fails.

<details><summary>Tests (5)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `into-slice` &middot; `short` &middot; `end-of-file` &middot; `empty-slice` &middot; `closed` (raises)

</details>

### <a name="val-writevec"></a>`writeVec`

```sml
val writeVec : file_desc * Word8VectorSlice.slice -> int
```

`writeVec (fd, sl)` writes the bytes of `sl` and is the number it wrote, which may be fewer.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the write fails.

<details><summary>Tests (5)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `slice` &middot; `empty-slice` &middot; `twice` &middot; `closed` (raises) &middot; `read-only` (raises)

</details>

### <a name="val-writearr"></a>`writeArr`

```sml
val writeArr : file_desc * Word8ArraySlice.slice -> int
```

`writeArr (fd, sl)` writes the bytes of the array stretch `sl` and is the number it wrote.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the write fails.

<details><summary>Tests (3)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `slice` &middot; `binary` &middot; `closed` (raises)

</details>

### <a name="type-whence"></a>`whence`

```sml
datatype whence
  = SEEK_SET
  | SEEK_CUR
  | SEEK_END
```

What a position given to [`lseek`](#val-lseek) or a lock is counted from.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-seek_set"></a>`SEEK_SET` |  | the start of the file |
| <a name="con-seek_cur"></a>`SEEK_CUR` |  | where the descriptor is now |
| <a name="con-seek_end"></a>`SEEK_END` |  | the end of the file |

### <a name="str-fd"></a>`FD`

The flags of a descriptor itself, which [`dup`](#val-dup) does not carry over.

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype | The type of a set of flags. |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val | `toWord fl` is the word whose bits are the flags of `fl`. |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val | `fromWord w` is the set of the flags that the bits of `w` name. |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val | Every flag the system uses here. |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val | `flags l` is the union of the sets of `l`: a flag is in it when it is in one of them. |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val | `intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them. |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val | `clear (fl, gl)` is `gl` without the flags of `fl`. |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val | `allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`. |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val | `anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`. |

#### <a name="val-fd.cloexec"></a>`cloexec`

```sml
val cloexec : flags
```

Close this descriptor when the process runs another program.

A descriptor that has just been made does not have it.

<details><summary>Tests (2)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `not-inherited-by-dup` &middot; `per-descriptor`

</details>

### <a name="str-o"></a>`O`

The flags of the open file that a descriptor is on, which [`dup`](#val-dup) shares.

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype | The type of a set of flags. |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val | `toWord fl` is the word whose bits are the flags of `fl`. |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val | `fromWord w` is the set of the flags that the bits of `w` name. |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val | Every flag the system uses here. |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val | `flags l` is the union of the sets of `l`: a flag is in it when it is in one of them. |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val | `intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them. |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val | `clear (fl, gl)` is `gl` without the flags of `fl`. |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val | `allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`. |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val | `anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`. |

#### <a name="val-o.append"></a>`append`

```sml
val append : flags
```

Every write goes to the end of the file.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `getfl-after-openf`

</details>

#### <a name="val-o.nonblock"></a>`nonblock`

```sml
val nonblock : flags
```

A read or a write that would wait fails instead.

<details><summary>Tests (2)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `setfl` &middot; `new-pipe`

</details>

#### <a name="val-o.sync"></a>`sync`

```sml
val sync : flags
```

A write returns only once the data have reached the device.

<details><summary>Tests (2)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `getfl-after-openf` &middot; `not-set`

</details>

### <a name="type-open_mode"></a>`open_mode`

```sml
datatype open_mode
  = O_RDONLY
  | O_WRONLY
  | O_RDWR
```

What a file was opened for.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-o_rdonly"></a>`O_RDONLY` |  | reading only |
| <a name="con-o_wronly"></a>`O_WRONLY` |  | writing only |
| <a name="con-o_rdwr"></a>`O_RDWR` |  | both |

### <a name="val-dupfd"></a>`dupfd`

```sml
val dupfd : {old : file_desc, base : file_desc}
            -> file_desc
```

`dupfd {old, base}` is `dup old`, but the number it gives is at least `base`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `old` is not open, or no such descriptor is
free.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-dupfd.old"></a>`old` | `file_desc` |  |
| <a name="fld-dupfd.base"></a>`base` | `file_desc` |  |

<details><summary>Tests (3)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `base-0-is-dup` &middot; `at-least-base` &middot; `same-file`

</details>

### <a name="val-getfd"></a>`getfd`

```sml
val getfd : file_desc -> FD.flags
```

`getfd fd` is the flags of the descriptor `fd` itself.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `new-descriptor`

</details>

### <a name="val-setfd"></a>`setfd`

```sml
val setfd : file_desc * FD.flags -> unit
```

`setfd (fd, fl)` sets the flags of the descriptor `fd` to `fl`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open.

<details><summary>Tests (2)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `cloexec` &middot; `clear`

</details>

### <a name="val-getfl"></a>`getfl`

```sml
val getfl : file_desc -> O.flags * open_mode
```

`getfl fd` is the flags of the open file that `fd` is on, and what it was opened for.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open.

<details><summary>Tests (2)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `pipe-ends` &middot; `no-append`

</details>

### <a name="val-setfl"></a>`setfl`

```sml
val setfl : file_desc * O.flags -> unit
```

`setfl (fd, fl)` sets the flags of the open file that `fd` is on.

What a file was opened for cannot be changed this way.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open.

<details><summary>Tests (5)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `append` &middot; `append-writes-at-end` &middot; `clear` &middot; `cleared-append-writes-at-offset` &middot; `keeps-access-mode`

</details>

### <a name="val-lseek"></a>`lseek`

```sml
val lseek : file_desc * Position.int * whence
            -> Position.int
```

`lseek (fd, n, whence)` moves `fd` to `n` bytes from the place `whence` names, and is where it now is.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` cannot be positioned -- a pipe, a socket or
a terminal.

<details><summary>Tests (3)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `current-position` &middot; `then-write` &middot; `beyond-the-end`

</details>

### <a name="val-fsync"></a>`fsync`

```sml
val fsync : file_desc -> unit
```

`fsync fd` waits until what was written to `fd` has reached the device.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open, or the write fails.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `written-file`

</details>

### <a name="type-lock_type"></a>`lock_type`

```sml
datatype lock_type
  = F_RDLCK
  | F_WRLCK
  | F_UNLCK
```

What a lock is for, and what [`F_UNLCK`](#con-f_unlck) says when a lock is asked about.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-f_rdlck"></a>`F_RDLCK` |  | a read lock: others may read, none may write |
| <a name="con-f_wrlck"></a>`F_WRLCK` |  | a write lock: none may read or write |
| <a name="con-f_unlck"></a>`F_UNLCK` |  | no lock; as an answer, that nothing blocks |

### <a name="str-flock"></a>`FLock`

A description of a stretch of a file and what is to be done with it.

> **Implementation** `Posix.IO.FLock/is-a-flock`. The lock operations are
> `fcntl` with a `struct flock`, and a `flock` here is that record.

#### <a name="type-flock.flock"></a>`flock`

```sml
type flock
```

The type of a lock description.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `fields`

</details>

#### <a name="val-flock.flock"></a>`flock`

```sml
val flock : {
              ltype : lock_type,
              whence : whence,
              start : Position.int,
              len : Position.int,
              pid : pid option
            } -> flock
```

`flock {ltype, whence, start, len, pid}` describes a lock of kind `ltype` on the stretch that the rest names.

`len` of zero reaches to the end of the file, however far it grows.
`pid` is meaningful only in what [`getlk`](#val-getlk) gives back.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-flock.flock.ltype"></a>`ltype` | `lock_type` |  |
| <a name="fld-flock.flock.whence"></a>`whence` | `whence` |  |
| <a name="fld-flock.flock.start"></a>`start` | `Position.int` |  |
| <a name="fld-flock.flock.len"></a>`len` | `Position.int` |  |
| <a name="fld-flock.flock.pid"></a>`pid` | `pid option` |  |

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `fields`

</details>

#### <a name="val-flock.ltype"></a>`ltype`

```sml
val ltype : flock -> lock_type
```

`ltype fl` is the kind of lock `fl` describes.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `read-lock`

</details>

#### <a name="val-flock.whence"></a>`whence`

```sml
val whence : flock -> whence
```

`whence fl` is what `start fl` is counted from.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `SEEK_END`

</details>

#### <a name="val-flock.start"></a>`start`

```sml
val start : flock -> Position.int
```

`start fl` is where the locked stretch begins.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `negative`

</details>

#### <a name="val-flock.len"></a>`len`

```sml
val len : flock -> Position.int
```

`len fl` is how long the locked stretch is, 0 meaning to the end of the file.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `zero`

</details>

#### <a name="val-flock.pid"></a>`pid`

```sml
val pid : flock -> pid option
```

`pid fl` is the process holding the lock, when [`getlk`](#val-getlk) found one.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `SOME`

</details>

### <a name="val-getlk"></a>`getlk`

```sml
val getlk : file_desc * FLock.flock -> FLock.flock
```

`getlk (fd, fl)` asks what would block the lock `fl`, without taking it.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the question is refused.

> **Reading** `Posix.IO.getlk/F_UNLCK-means-free`. When nothing blocks the
> described lock, POSIX reports that as an answer of kind [`F_UNLCK`](#con-f_unlck); and
> since a process's own locks never block it, its own lock is reported
> that way too.

<details><summary>Tests (2)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `own-lock-does-not-block` &middot; `no-lock`

</details>

### <a name="val-setlk"></a>`setlk`

```sml
val setlk : file_desc * FLock.flock -> FLock.flock
```

`setlk (fd, fl)` takes or releases the lock `fl` without waiting.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if another process holds a lock in the way.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `write-lock`

</details>

### <a name="val-setlkw"></a>`setlkw`

```sml
val setlkw : file_desc * FLock.flock -> FLock.flock
```

`setlkw (fd, fl)` takes or releases the lock `fl`, waiting until it can.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the wait is interrupted or the lock is
refused.

<details><summary>Tests (1)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `write-lock`

</details>

### <a name="val-mkbinreader"></a>`mkBinReader`

```sml
val mkBinReader : {
                    fd : file_desc,
                    name : string,
                    initBlkMode : bool
                  } -> BinPrimIO.reader
```

`mkBinReader {fd, name, initBlkMode}` is a [`PRIM_IO`](../sig/PRIM_IO.md) reader of bytes over `fd`.

`name` is what an [`IO.Io`](../sig/IO.md#exn-io) from it will carry; `initBlkMode` says whether
the descriptor starts in blocking mode.

> **Implementation** `Posix.IO.mkBinReader/positions`. Only a regular file
> has positions, so `getPos`, `setPos`, `endPos` and `verifyPos` are
> `NONE` for a pipe, a socket or a terminal.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mkbinreader.fd"></a>`fd` | `file_desc` |  |
| <a name="fld-mkbinreader.name"></a>`name` | `string` |  |
| <a name="fld-mkbinreader.initblkmode"></a>`initBlkMode` | `bool` |  |

<details><summary>Tests (4)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `readVec` &middot; `name` &middot; `stream` &middot; `from-a-pipe`

</details>

### <a name="val-mktextreader"></a>`mkTextReader`

```sml
val mkTextReader : {
                     fd : file_desc,
                     name : string,
                     initBlkMode : bool
                   } -> TextPrimIO.reader
```

`mkTextReader {fd, name, initBlkMode}` is a [`PRIM_IO`](../sig/PRIM_IO.md) reader of characters over `fd`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mktextreader.fd"></a>`fd` | `file_desc` |  |
| <a name="fld-mktextreader.name"></a>`name` | `string` |  |
| <a name="fld-mktextreader.initblkmode"></a>`initBlkMode` | `bool` |  |

<details><summary>Tests (4)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `readVec` &middot; `name` &middot; `stream-lines` &middot; `from-a-pipe`

</details>

### <a name="val-mkbinwriter"></a>`mkBinWriter`

```sml
val mkBinWriter : {
                    fd : file_desc,
                    name : string,
                    appendMode : bool,
                    initBlkMode : bool,
                    chunkSize : int
                  } -> BinPrimIO.writer
```

`mkBinWriter {fd, name, appendMode, initBlkMode, chunkSize}` is a [`PRIM_IO`](../sig/PRIM_IO.md) writer of bytes over `fd`.

`appendMode` says whether every write goes to the end of the file, and
`chunkSize` how much the writer likes to be given at a time.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mkbinwriter.fd"></a>`fd` | `file_desc` |  |
| <a name="fld-mkbinwriter.name"></a>`name` | `string` |  |
| <a name="fld-mkbinwriter.appendmode"></a>`appendMode` | `bool` |  |
| <a name="fld-mkbinwriter.initblkmode"></a>`initBlkMode` | `bool` |  |
| <a name="fld-mkbinwriter.chunksize"></a>`chunkSize` | `int` |  |

<details><summary>Tests (5)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `writeVec` &middot; `name-and-chunkSize` &middot; `stream` &middot; `append-mode` &middot; `into-a-pipe`

</details>

### <a name="val-mktextwriter"></a>`mkTextWriter`

```sml
val mkTextWriter : {
                     fd : file_desc,
                     name : string,
                     appendMode : bool,
                     initBlkMode : bool,
                     chunkSize : int
                   } -> TextPrimIO.writer
```

`mkTextWriter {fd, name, appendMode, initBlkMode, chunkSize}` is a [`PRIM_IO`](../sig/PRIM_IO.md) writer of characters over `fd`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mktextwriter.fd"></a>`fd` | `file_desc` |  |
| <a name="fld-mktextwriter.name"></a>`name` | `string` |  |
| <a name="fld-mktextwriter.appendmode"></a>`appendMode` | `bool` |  |
| <a name="fld-mktextwriter.initblkmode"></a>`initBlkMode` | `bool` |  |
| <a name="fld-mktextwriter.chunksize"></a>`chunkSize` | `int` |  |

<details><summary>Tests (4)</summary>

For `Posix.IO`, in [tests/basis/posix\_io.sml](../../../../tests/basis/posix_io.sml): `writeVec` &middot; `name-and-chunkSize` &middot; `stream` &middot; `into-a-pipe`

</details>

## See also

[`POSIX_FILE_SYS`](../sig/POSIX_FILE_SYS.md), [`PRIM_IO`](../sig/PRIM_IO.md), [`POSIX`](../sig/POSIX.md), [`TEXT_IO`](../sig/TEXT_IO.md), [`BIN_IO`](../sig/BIN_IO.md)

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_io.sml; do not edit.</sub>
