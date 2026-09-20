# signature POSIX_FILE_SYS

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **POSIX_FILE_SYS**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 91 of 91 entries documented |
| Tests | 196 checks of 78 entries |
| Source | [lib/basis/sig\_posix\_file\_sys.sml](../../../../lib/basis/sig_posix_file_sys.sml) |

## Synopsis

```sml
signature POSIX_FILE_SYS
structure Posix.FileSys : POSIX_FILE_SYS  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.FileSys` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

Files and directories as POSIX has them: opening them, linking and
removing them, and reading and setting what the system records about them.

Where [`OS_FILE_SYS`](../sig/OS_FILE_SYS.md) offers what any system can do, this offers the system
calls: `open`, [`creat`](#val-creat), [`link`](#val-link), [`mkfifo`](#val-mkfifo), [`stat`](#val-stat), [`chmod`](#val-chmod), [`chown`](#val-chown),
[`umask`](#val-umask). What it gives back for an open file is a [`file_desc`](#type-file_desc), which
[`POSIX_IO`](../sig/POSIX_IO.md) reads and writes.

Permissions are a set of flags, the substructure [`S`](#str-s), and so are the
options of [`openf`](#val-openf), the substructure [`O`](#str-o); both are [`BIT_FLAGS`](../sig/BIT_FLAGS.md). What
[`stat`](#val-stat) reports is an [`ST.stat`](#type-st.stat), which the functions of [`ST`](#str-st) take apart.

Every failure raises [`OS.SysErr`](../sig/OS.md#exn-syserr) with the `errno` the call left; the
conditions are the ones [`POSIX_ERROR`](../sig/POSIX_ERROR.md) names.

> **Erratum** `POSIX_FILE_SYS/flexible-types`. The types are kept as the page
> writes them. What the text says about them is checked in the suite rather
> than written here: [`uid`](#type-uid), [`gid`](#type-gid) and [`file_desc`](#type-file_desc) are those of
> [`Posix.ProcEnv`](../sig/POSIX.md#str-procenv), [`dirstream`](#type-dirstream) is [`OS.FileSys.dirstream`](../sig/OS_FILE_SYS.md#type-dirstream), and [`access_mode`](#type-access_mode)
> is [`OS.FileSys.access_mode`](../sig/OS_FILE_SYS.md#type-access_mode).

> **Reading** `Posix.FileSys/empty-path-raises`. An empty path raises
> [`OS.SysErr`](../sig/OS.md#exn-syserr) with `noent`, as the system would, although inside the library
> the empty string means "use the descriptor instead".

## Interface

<pre>
signature POSIX_FILE_SYS =
sig
  eqtype <a href="#type-uid">uid</a>

  eqtype <a href="#type-gid">gid</a>

  eqtype <a href="#type-file_desc">file_desc</a>

  val <a href="#val-fdtoword">fdToWord</a> : file_desc -&gt; SysWord.word

  val <a href="#val-wordtofd">wordToFD</a> : SysWord.word -&gt; file_desc

  val <a href="#val-fdtoiod">fdToIOD</a> : file_desc -&gt; OS.IO.iodesc

  val <a href="#val-iodtofd">iodToFD</a> : OS.IO.iodesc -&gt; file_desc option

  type <a href="#type-dirstream">dirstream</a>

  val <a href="#val-opendir">opendir</a> : string -&gt; dirstream

  val <a href="#val-readdir">readdir</a> : dirstream -&gt; string option

  val <a href="#val-rewinddir">rewinddir</a> : dirstream -&gt; unit

  val <a href="#val-closedir">closedir</a> : dirstream -&gt; unit

  val <a href="#val-chdir">chdir</a> : string -&gt; unit

  val <a href="#val-getcwd">getcwd</a> : unit -&gt; string

  val <a href="#val-stdin">stdin</a> : file_desc

  val <a href="#val-stdout">stdout</a> : file_desc

  val <a href="#val-stderr">stderr</a> : file_desc

  structure <a href="#str-s">S</a> :
  sig
    eqtype <a href="#type-s.mode">mode</a>

    include BIT_FLAGS
      where type flags = mode

    val <a href="#val-s.irwxu">irwxu</a> : mode

    val <a href="#val-s.irusr">irusr</a> : mode

    val <a href="#val-s.iwusr">iwusr</a> : mode

    val <a href="#val-s.ixusr">ixusr</a> : mode

    val <a href="#val-s.irwxg">irwxg</a> : mode

    val <a href="#val-s.irgrp">irgrp</a> : mode

    val <a href="#val-s.iwgrp">iwgrp</a> : mode

    val <a href="#val-s.ixgrp">ixgrp</a> : mode

    val <a href="#val-s.irwxo">irwxo</a> : mode

    val <a href="#val-s.iroth">iroth</a> : mode

    val <a href="#val-s.iwoth">iwoth</a> : mode

    val <a href="#val-s.ixoth">ixoth</a> : mode

    val <a href="#val-s.isuid">isuid</a> : mode

    val <a href="#val-s.isgid">isgid</a> : mode
  end

  structure <a href="#str-o">O</a> :
  sig
    include BIT_FLAGS

    val <a href="#val-o.append">append</a> : flags

    val <a href="#val-o.excl">excl</a> : flags

    val <a href="#val-o.noctty">noctty</a> : flags

    val <a href="#val-o.nonblock">nonblock</a> : flags

    val <a href="#val-o.sync">sync</a> : flags

    val <a href="#val-o.trunc">trunc</a> : flags
  end

  datatype <a href="#type-open_mode">open_mode</a>
    = <a href="#con-o_rdonly">O_RDONLY</a>
    | <a href="#con-o_wronly">O_WRONLY</a>
    | <a href="#con-o_rdwr">O_RDWR</a>

  val <a href="#val-openf">openf</a> : string * open_mode * O.flags -&gt; file_desc

  val <a href="#val-createf">createf</a> : string * open_mode * O.flags * S.mode
                -&gt; file_desc

  val <a href="#val-creat">creat</a> : string * S.mode -&gt; file_desc

  val <a href="#val-umask">umask</a> : S.mode -&gt; S.mode

  val <a href="#val-link">link</a> : {<a href="#fld-link.old">old</a> : string, <a href="#fld-link.new">new</a> : string} -&gt; unit

  val <a href="#val-mkdir">mkdir</a> : string * S.mode -&gt; unit

  val <a href="#val-mkfifo">mkfifo</a> : string * S.mode -&gt; unit

  val <a href="#val-unlink">unlink</a> : string -&gt; unit

  val <a href="#val-rmdir">rmdir</a> : string -&gt; unit

  val <a href="#val-rename">rename</a> : {<a href="#fld-rename.old">old</a> : string, <a href="#fld-rename.new">new</a> : string} -&gt; unit

  val <a href="#val-symlink">symlink</a> : {<a href="#fld-symlink.old">old</a> : string, <a href="#fld-symlink.new">new</a> : string} -&gt; unit

  val <a href="#val-readlink">readlink</a> : string -&gt; string

  eqtype <a href="#type-dev">dev</a>

  val <a href="#val-wordtodev">wordToDev</a> : SysWord.word -&gt; dev

  val <a href="#val-devtoword">devToWord</a> : dev -&gt; SysWord.word

  eqtype <a href="#type-ino">ino</a>

  val <a href="#val-wordtoino">wordToIno</a> : SysWord.word -&gt; ino

  val <a href="#val-inotoword">inoToWord</a> : ino -&gt; SysWord.word

  structure <a href="#str-st">ST</a> :
  sig
    type <a href="#type-st.stat">stat</a>

    val <a href="#val-st.isdir">isDir</a> : stat -&gt; bool

    val <a href="#val-st.ischr">isChr</a> : stat -&gt; bool

    val <a href="#val-st.isblk">isBlk</a> : stat -&gt; bool

    val <a href="#val-st.isreg">isReg</a> : stat -&gt; bool

    val <a href="#val-st.isfifo">isFIFO</a> : stat -&gt; bool

    val <a href="#val-st.islink">isLink</a> : stat -&gt; bool

    val <a href="#val-st.issock">isSock</a> : stat -&gt; bool

    val <a href="#val-st.mode">mode</a> : stat -&gt; S.mode

    val <a href="#val-st.ino">ino</a> : stat -&gt; ino

    val <a href="#val-st.dev">dev</a> : stat -&gt; dev

    val <a href="#val-st.nlink">nlink</a> : stat -&gt; int

    val <a href="#val-st.uid">uid</a> : stat -&gt; uid

    val <a href="#val-st.gid">gid</a> : stat -&gt; gid

    val <a href="#val-st.size">size</a> : stat -&gt; Position.int

    val <a href="#val-st.atime">atime</a> : stat -&gt; Time.time

    val <a href="#val-st.mtime">mtime</a> : stat -&gt; Time.time

    val <a href="#val-st.ctime">ctime</a> : stat -&gt; Time.time
  end

  val <a href="#val-stat">stat</a> : string -&gt; ST.stat

  val <a href="#val-lstat">lstat</a> : string -&gt; ST.stat

  val <a href="#val-fstat">fstat</a> : file_desc -&gt; ST.stat

  datatype <a href="#type-access_mode">access_mode</a>
    = <a href="#con-a_read">A_READ</a>
    | <a href="#con-a_write">A_WRITE</a>
    | <a href="#con-a_exec">A_EXEC</a>

  val <a href="#val-access">access</a> : string * access_mode list -&gt; bool

  val <a href="#val-chmod">chmod</a> : string * S.mode -&gt; unit

  val <a href="#val-fchmod">fchmod</a> : file_desc * S.mode -&gt; unit

  val <a href="#val-chown">chown</a> : string * uid * gid -&gt; unit

  val <a href="#val-fchown">fchown</a> : file_desc * uid * gid -&gt; unit

  val <a href="#val-utime">utime</a> : string
              * {<a href="#fld-utime.actime">actime</a> : Time.time, <a href="#fld-utime.modtime">modtime</a> : Time.time} option
              -&gt; unit

  val <a href="#val-ftruncate">ftruncate</a> : file_desc * Position.int -&gt; unit

  val <a href="#val-pathconf">pathconf</a> : string * string -&gt; SysWord.word option

  val <a href="#val-fpathconf">fpathconf</a> : file_desc * string -&gt; SysWord.word option
end
</pre>

### <a name="type-uid"></a>`uid`

```sml
eqtype uid
```

The type of the number that names a user, the one of [`Posix.ProcEnv`](../sig/POSIX.md#str-procenv).

### <a name="type-gid"></a>`gid`

```sml
eqtype gid
```

The type of the number that names a group.

### <a name="type-file_desc"></a>`file_desc`

```sml
eqtype file_desc
```

The type of an open file descriptor.

### <a name="val-fdtoword"></a>`fdToWord`

```sml
val fdToWord : file_desc -> SysWord.word
```

`fdToWord fd` is the number the system knows `fd` by.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `inverts-wordToFD` &middot; `distinct-descriptors`

</details>

### <a name="val-wordtofd"></a>`wordToFD`

```sml
val wordToFD : SysWord.word -> file_desc
```

`wordToFD w` is the descriptor numbered `w`, whether or not it is open.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; wordToFD makes a new file\_desc that is not equal (=) to the file\_desc with the same number: equality of file\_desc is that of the object

</details>

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `inverts-fdToWord`

</details>

### <a name="val-fdtoiod"></a>`fdToIOD`

```sml
val fdToIOD : file_desc -> OS.IO.iodesc
```

`fdToIOD fd` is `fd` as the [`OS.IO.iodesc`](../sig/OS_IO.md#type-iodesc) that [`OS.IO.poll`](../sig/OS_IO.md#val-poll) takes.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `same-descriptor` &middot; `kind-of-a-file`

</details>

### <a name="val-iodtofd"></a>`iodToFD`

```sml
val iodToFD : OS.IO.iodesc -> file_desc option
```

`iodToFD iod` is `SOME` of the descriptor that `iod` is, or `NONE` when it is not one.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `inverts-fdToIOD` &middot; `stdout` &middot; `descriptor-of-a-stream`

</details>

### <a name="type-dirstream"></a>`dirstream`

```sml
type dirstream
```

The type of an open directory being read, the [`dirstream`](#type-dirstream) of [`OS.FileSys`](../sig/OS.md#str-filesys).

### <a name="val-opendir"></a>`opendir`

```sml
val opendir : string -> dirstream
```

`opendir p` opens the directory `p` for reading.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is no directory, or may not be read.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `positioned-at-first-entry` &middot; `missing` (raises) &middot; `a-file` (raises)

</details>

### <a name="val-readdir"></a>`readdir`

```sml
val readdir : dirstream -> string option
```

`readdir d` is `SOME` of the next name in `d`, or `NONE` when there are no more.

The names are arcs, and `"."` and `".."` are not among them.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the directory cannot be read.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `entries` &middot; `empty-directory` &middot; `NONE-at-end`

</details>

### <a name="val-rewinddir"></a>`rewinddir`

```sml
val rewinddir : dirstream -> unit
```

`rewinddir d` puts `d` back at its first name.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `reads-again` &middot; `after-one-entry`

</details>

### <a name="val-closedir"></a>`closedir`

```sml
val closedir : dirstream -> unit
```

`closedir d` closes `d`.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `twice` &middot; `then-opendir-again`

</details>

### <a name="val-chdir"></a>`chdir`

```sml
val chdir : string -> unit
```

`chdir p` makes `p` the current directory of the process.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is no directory, or may not be entered.

<details><summary>Tests (6)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `into-subdirectory` &middot; `relative-names` &middot; `back-up` &middot; `absolute` &middot; `missing` (raises) &middot; `failure-keeps-directory`

</details>

### <a name="val-getcwd"></a>`getcwd`

```sml
val getcwd : unit -> string
```

`getcwd ()` is the current directory, as an absolute path.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if it cannot be found.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `absolute` &middot; `is-the-directory`

</details>

### <a name="val-stdin"></a>`stdin`

```sml
val stdin : file_desc
```

The descriptor the program reads its input from.

> **Implementation** `Posix.FileSys.stdin/is-0`. The three standard
> descriptors are the words 0, 1 and 2, which POSIX fixes and the page
> does not state.

<details><summary>Other implementations (1)</summary>

- **Poly/ML 5.9.2** &mdash; wordToFD 0w0 is not equal (=) to stdin: equality of file\_desc is that of the object

</details>

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-0` &middot; `wordToFD-0`

</details>

### <a name="val-stdout"></a>`stdout`

```sml
val stdout : file_desc
```

The descriptor the program writes its output to.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-1` &middot; `is-open`

</details>

### <a name="val-stderr"></a>`stderr`

```sml
val stderr : file_desc
```

The descriptor the program writes its errors to.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-2` &middot; `dup`

</details>

### <a name="str-s"></a>`S`

The permission bits of a file, as a set of flags.

#### <a name="type-s.mode"></a>`mode`

```sml
eqtype mode
```

The type of a set of permission bits.

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS
  where type flags = mode`

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

#### <a name="val-s.irwxu"></a>`irwxu`

```sml
val irwxu : mode
```

Read, write and run, for the owner: [`irusr`](#val-s.irusr), [`iwusr`](#val-s.iwusr) and [`ixusr`](#val-s.ixusr) together.

> **Implementation** `Posix.FileSys.S/values-of-the-C-binding`. The bits
> are the ones of the system's `<sys/stat.h>`: [`irwxu`](#val-s.irwxu) is 0700 through
> [`isuid`](#val-s.isuid) 04000 and [`isgid`](#val-s.isgid) 02000, and [`all`](../sig/BIT_FLAGS.md#val-all) is 07777, every bit that
> [`chmod`](#val-chmod) sets, the sticky bit included.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-irusr-iwusr-ixusr` &middot; `chmod`

</details>

#### <a name="val-s.irusr"></a>`irusr`

```sml
val irusr : mode
```

The owner may read.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.iwusr"></a>`iwusr`

```sml
val iwusr : mode
```

The owner may write.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.ixusr"></a>`ixusr`

```sml
val ixusr : mode
```

The owner may run it, or enter it when it is a directory.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.irwxg"></a>`irwxg`

```sml
val irwxg : mode
```

Read, write and run, for the group.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-irgrp-iwgrp-ixgrp` &middot; `chmod`

</details>

#### <a name="val-s.irgrp"></a>`irgrp`

```sml
val irgrp : mode
```

The group may read.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.iwgrp"></a>`iwgrp`

```sml
val iwgrp : mode
```

The group may write.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.ixgrp"></a>`ixgrp`

```sml
val ixgrp : mode
```

The group may run it.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.irwxo"></a>`irwxo`

```sml
val irwxo : mode
```

Read, write and run, for everyone else.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-iroth-iwoth-ixoth` &middot; `chmod`

</details>

#### <a name="val-s.iroth"></a>`iroth`

```sml
val iroth : mode
```

Everyone may read.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.iwoth"></a>`iwoth`

```sml
val iwoth : mode
```

Everyone may write.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.ixoth"></a>`ixoth`

```sml
val ixoth : mode
```

Everyone may run it.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.isuid"></a>`isuid`

```sml
val isuid : mode
```

Run the program as its owner rather than as whoever started it.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `distinct-from-the-others` &middot; `chmod`

</details>

#### <a name="val-s.isgid"></a>`isgid`

```sml
val isgid : mode
```

Run the program with the file's group.

> **Implementation** `Posix.FileSys.S.isgid/may-not-stick`. The owner may
> always set [`isuid`](#val-s.isuid); [`isgid`](#val-s.isgid) is only bound to stay set when the file's
> group is one of the process's own groups.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

### <a name="str-o"></a>`O`

The options of [`openf`](#val-openf) and [`createf`](#val-createf).

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

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `writes-at-end`

</details>

#### <a name="val-o.excl"></a>`excl`

```sml
val excl : flags
```

Fail rather than open a file that is there already; for [`createf`](#val-createf).

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `existing-file` (raises) &middot; `new-file`

</details>

#### <a name="val-o.noctty"></a>`noctty`

```sml
val noctty : flags
```

Do not let this file become the process's controlling terminal.

> **Reading** `Posix.FileSys.O.noctty/only-for-terminals`. A regular file
> never becomes a controlling terminal, so on one this flag is only
> checked to leave reading as it was.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `regular-file`

</details>

#### <a name="val-o.nonblock"></a>`nonblock`

```sml
val nonblock : flags
```

A read or a write that would wait fails instead.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `regular-file` &middot; `fifo-opens-at-once` &middot; `fifo-without-reader` (raises)

</details>

#### <a name="val-o.sync"></a>`sync`

```sml
val sync : flags
```

A write returns only once the data have reached the device.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `writes`

</details>

#### <a name="val-o.trunc"></a>`trunc`

```sml
val trunc : flags
```

Empty the file when opening it.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `truncates` &middot; `then-writes`

</details>

### <a name="type-open_mode"></a>`open_mode`

```sml
datatype open_mode
  = O_RDONLY
  | O_WRONLY
  | O_RDWR
```

What a file is opened for.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-o_rdonly"></a>`O_RDONLY` |  | reading only |
| <a name="con-o_wronly"></a>`O_WRONLY` |  | writing only |
| <a name="con-o_rdwr"></a>`O_RDWR` |  | both |

### <a name="val-openf"></a>`openf`

```sml
val openf : string * open_mode * O.flags -> file_desc
```

`openf (p, mode, flags)` opens the file `p`, which must exist, and is a descriptor on it.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing, or may not be opened that
way.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `missing-file` (raises) &middot; `reads-the-file` &middot; `keeps-contents`

</details>

### <a name="val-createf"></a>`createf`

```sml
val createf : string * open_mode * O.flags * S.mode
              -> file_desc
```

`createf (p, mode, flags, perms)` opens `p`, making it with the permissions `perms` when it is not there.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` cannot be opened or made.

> **Reading** `Posix.FileSys.createf/existing-file-is-opened`. The page
> speaks of the permissions only for a file that has to be made, so a file
> that is there already is opened as it stands: neither its contents nor
> its permissions are touched, unless [`O.trunc`](#val-o.trunc) is given.

<details><summary>Tests (6)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `mode-less-umask` &middot; `mode-with-empty-umask` &middot; `open-mode` &middot; `existing-file` &middot; `existing-mode-kept` &middot; `with-trunc`

</details>

### <a name="val-creat"></a>`creat`

```sml
val creat : string * S.mode -> file_desc
```

`creat (p, perms)` is `createf (p, O_WRONLY, O.flags [O.trunc], perms)`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` cannot be opened or made.

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `truncates` &middot; `mode-less-umask` &middot; `writes` &middot; `write-only` (raises)

</details>

### <a name="val-umask"></a>`umask`

```sml
val umask : S.mode -> S.mode
```

`umask m` makes `m` the set of permission bits withheld from files this process creates, and is the old one.

> **Reading** `Posix.FileSys.umask/not-for-chmod`. The mask applies to files
> that are created; [`chmod`](#val-chmod) sets what it is given, mask or no mask.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `returns-previous` &middot; `set-then-read` &middot; `removes-permissions`

</details>

### <a name="val-link"></a>`link`

```sml
val link : {old : string, new : string} -> unit
```

`link {old, new}` makes `new` another name for the file `old`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `old` names nothing, `new` is there already, or
the two are on different file systems.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-link.old"></a>`old` | `string` |  |
| <a name="fld-link.new"></a>`new` | `string` |  |

<details><summary>Tests (6)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `same-contents` &middot; `shared-file` &middot; `same-inode` &middot; `link-count` &middot; `directory` (raises) &middot; `missing-file` (raises)

</details>

### <a name="val-mkdir"></a>`mkdir`

```sml
val mkdir : string * S.mode -> unit
```

`mkdir (p, perms)` makes a directory `p` with the permissions `perms`, less the mask.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is there already, or cannot be made.

<details><summary>Tests (7)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `makes-a-directory` &middot; `mode` &middot; `mode-less-umask` &middot; `owner-only` &middot; `mask-unchanged` &middot; `existing` (raises) &middot; `missing-parent` (raises)

</details>

### <a name="val-mkfifo"></a>`mkfifo`

```sml
val mkfifo : string * S.mode -> unit
```

`mkfifo (p, perms)` makes a named pipe `p` with the permissions `perms`, less the mask.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is there already, or cannot be made.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `makes-a-fifo` &middot; `mode-less-umask` &middot; `existing` (raises)

</details>

### <a name="val-unlink"></a>`unlink`

```sml
val unlink : string -> unit
```

`unlink p` removes the name `p`; the file goes when its last name does.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing, or may not be removed.

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `removes` &middot; `decrements-link-count` &middot; `symbolic-link` &middot; `open-file` &middot; `missing` (raises)

</details>

### <a name="val-rmdir"></a>`rmdir`

```sml
val rmdir : string -> unit
```

`rmdir p` removes the directory `p`, which must be empty.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is not an empty directory, or may not be
removed.

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `removes` &middot; `not-empty` (raises) &middot; `a-file` (raises) &middot; `missing` (raises)

</details>

### <a name="val-rename"></a>`rename`

```sml
val rename : {old : string, new : string} -> unit
```

`rename {old, new}` renames `old` to `new`, replacing what `new` named.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `old` names nothing, or the rename is refused.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-rename.old"></a>`old` | `string` |  |
| <a name="fld-rename.new"></a>`new` | `string` |  |

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `file` &middot; `directory` &middot; `into-directory` &middot; `missing` (raises)

</details>

### <a name="val-symlink"></a>`symlink`

```sml
val symlink : {old : string, new : string} -> unit
```

`symlink {old, new}` makes `new` a symbolic link holding the text `old`.

`old` need not name anything.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `new` is there already, or cannot be made.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-symlink.old"></a>`old` | `string` |  |
| <a name="fld-symlink.new"></a>`new` | `string` |  |

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `follows` &middot; `dangling` &middot; `through-a-directory` &middot; `existing-name` (raises)

</details>

### <a name="val-readlink"></a>`readlink`

```sml
val readlink : string -> string
```

`readlink p` is the text that the symbolic link `p` holds.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is no symbolic link.

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `text-of-the-link` &middot; `relative-path-kept` &middot; `absolute-path` &middot; `not-a-link` (raises) &middot; `missing` (raises)

</details>

### <a name="type-dev"></a>`dev`

```sml
eqtype dev
```

The type of the number that names a device.

### <a name="val-wordtodev"></a>`wordToDev`

```sml
val wordToDev : SysWord.word -> dev
```

`wordToDev w` is the device numbered `w`.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `inverts-devToWord`

</details>

### <a name="val-devtoword"></a>`devToWord`

```sml
val devToWord : dev -> SysWord.word
```

`devToWord d` is the number of the device `d`.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `inverts-wordToDev` &middot; `same-device`

</details>

### <a name="type-ino"></a>`ino`

```sml
eqtype ino
```

The type of the number that names a file within its device.

### <a name="val-wordtoino"></a>`wordToIno`

```sml
val wordToIno : SysWord.word -> ino
```

`wordToIno w` is the file numbered `w`.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `inverts-inoToWord`

</details>

### <a name="val-inotoword"></a>`inoToWord`

```sml
val inoToWord : ino -> SysWord.word
```

`inoToWord i` is the number of the file `i`.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `inverts-wordToIno` &middot; `distinct-files`

</details>

### <a name="str-st"></a>`ST`

What the system records about a file, and the functions that read it.

#### <a name="type-st.stat"></a>`stat`

```sml
type stat
```

The type of what [`stat`](#type-st.stat) reports about one file.

#### <a name="val-st.isdir"></a>`isDir`

```sml
val isDir : stat -> bool
```

`isDir st` is `true` when the file is a directory.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `directory` &middot; `current-directory`

</details>

#### <a name="val-st.ischr"></a>`isChr`

```sml
val isChr : stat -> bool
```

`isChr st` is `true` when the file is a character device, as `/dev/null` is.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `dev-null`

</details>

#### <a name="val-st.isblk"></a>`isBlk`

```sml
val isBlk : stat -> bool
```

`isBlk st` is `true` when the file is a block device.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `none-of-the-others`

</details>

#### <a name="val-st.isreg"></a>`isReg`

```sml
val isReg : stat -> bool
```

`isReg st` is `true` when the file is an ordinary file.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `regular-file`

</details>

#### <a name="val-st.isfifo"></a>`isFIFO`

```sml
val isFIFO : stat -> bool
```

`isFIFO st` is `true` when the file is a pipe, named or not.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `mkfifo` &middot; `pipe`

</details>

#### <a name="val-st.islink"></a>`isLink`

```sml
val isLink : stat -> bool
```

`isLink st` is `true` when the file is a symbolic link; only [`lstat`](#val-lstat) reports one.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `lstat-of-a-link` &middot; `dangling-link`

</details>

#### <a name="val-st.issock"></a>`isSock`

```sml
val isSock : stat -> bool
```

`isSock st` is `true` when the file is a socket.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `none-of-the-others` &middot; `socket`

</details>

#### <a name="val-st.mode"></a>`mode`

```sml
val mode : stat -> S.mode
```

`mode st` is the permission bits of the file.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; ST.mode includes the bits of the file type of st\_mode (S\_IFREG, S\_IFDIR, S\_IFIFO) besides the protection mode

</details>

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `regular-file` &middot; `directory` &middot; `fifo`

</details>

#### <a name="val-st.ino"></a>`ino`

```sml
val ino : stat -> ino
```

`ino st` is the number that names the file within its device.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `distinct-files` &middot; `same-file`

</details>

#### <a name="val-st.dev"></a>`dev`

```sml
val dev : stat -> dev
```

`dev st` is the number of the device the file is on.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `same-directory`

</details>

#### <a name="val-st.nlink"></a>`nlink`

```sml
val nlink : stat -> int
```

`nlink st` is how many names the file has.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `new-file` &middot; `three-links`

</details>

#### <a name="val-st.uid"></a>`uid`

```sml
val uid : stat -> uid
```

`uid st` is the user that owns the file.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `new-file`

</details>

#### <a name="val-st.gid"></a>`gid`

```sml
val gid : stat -> gid
```

`gid st` is the group of the file.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `new-file`

</details>

#### <a name="val-st.size"></a>`size`

```sml
val size : stat -> Position.int
```

`size st` is the size of the file in bytes.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `bytes` &middot; `empty` &middot; `lstat-of-a-link-is-its-text`

</details>

#### <a name="val-st.atime"></a>`atime`

```sml
val atime : stat -> Time.time
```

`atime st` is when the file was last read.

> **Implementation** `Posix.FileSys.ST.atime/whole-seconds`. The three
> times are kept in whole seconds, so they have no fraction.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `utime`

</details>

#### <a name="val-st.mtime"></a>`mtime`

```sml
val mtime : stat -> Time.time
```

`mtime st` is when the contents of the file were last changed.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `utime` &middot; `new-file`

</details>

#### <a name="val-st.ctime"></a>`ctime`

```sml
val ctime : stat -> Time.time
```

`ctime st` is when what the system records about the file last changed.

> **Reading** `Posix.FileSys.ST.ctime/utime-sets-it-to-now`. [`utime`](#val-utime)
> changes this time to now, not to either of the times it is given: it
> is the record that changed, not the contents.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `after-utime`

</details>

### <a name="val-stat"></a>`stat`

```sml
val stat : string -> ST.stat
```

`stat p` is what the system records about the file `p`, following symbolic links.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing.

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `empty-string` (raises) &middot; `missing` (raises) &middot; `follows-a-link` &middot; `dangling-link` (raises)

</details>

### <a name="val-lstat"></a>`lstat`

```sml
val lstat : string -> ST.stat
```

`lstat p` is what the system records about `p` itself, without following a symbolic link.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing.

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `empty-string` (raises) &middot; `missing` (raises) &middot; `regular-file` &middot; `the-link-itself`

</details>

### <a name="val-fstat"></a>`fstat`

```sml
val fstat : file_desc -> ST.stat
```

`fstat fd` is what the system records about the file that `fd` is open on.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `same-file` &middot; `kind` &middot; `directory`

</details>

### <a name="type-access_mode"></a>`access_mode`

```sml
datatype access_mode
  = A_READ
  | A_WRITE
  | A_EXEC
```

What one may want to do with a file, for [`access`](#val-access) to ask about.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-a_read"></a>`A_READ` |  | read it |
| <a name="con-a_write"></a>`A_WRITE` |  | write it |
| <a name="con-a_exec"></a>`A_EXEC` |  | run it, or enter it when it is a directory |

### <a name="val-access"></a>`access`

```sml
val access : string * access_mode list -> bool
```

`access (p, modes)` is `true` when the process may do all of `modes` to `p`, by its real user and group.

An empty list asks only whether `p` names something.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the question cannot be answered.

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `exists` &middot; `missing` &middot; `missing-read` &middot; `every-mode-of-the-list` &middot; `directory`

</details>

### <a name="val-chmod"></a>`chmod`

```sml
val chmod : string * S.mode -> unit
```

`chmod (p, perms)` sets the permission bits of `p` to `perms`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing, or the process does not own
it.

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `sets-mode` &middot; `not-masked` &middot; `no-permissions` &middot; `missing-file` (raises) &middot; `empty-path` (raises)

</details>

### <a name="val-fchmod"></a>`fchmod`

```sml
val fchmod : file_desc * S.mode -> unit
```

`fchmod (fd, perms)` sets the permission bits of the file that `fd` is open on.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open, or the process does not own the
file.

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `sets-mode` &middot; `fstat-agrees`

</details>

### <a name="val-chown"></a>`chown`

```sml
val chown : string * uid * gid -> unit
```

`chown (p, u, g)` makes `u` the owner and `g` the group of `p`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the change is refused.

> **Implementation** `Posix.FileSys.chown/only-what-is-allowed`. An
> unprivileged process may not give a file away, so the suite only checks
> setting the owner and group a file already has.

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `to-current-owner` &middot; `owner-is-process` &middot; `missing-file` (raises)

</details>

### <a name="val-fchown"></a>`fchown`

```sml
val fchown : file_desc * uid * gid -> unit
```

`fchown (fd, u, g)` is [`chown`](#val-chown) on the file that `fd` is open on.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the change is refused.

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `to-current-owner`

</details>

### <a name="val-utime"></a>`utime`

```sml
val utime : string
            * {actime : Time.time, modtime : Time.time} option
            -> unit
```

`utime (p, times)` sets when `p` was read and changed, or both to now when `times` is `NONE`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing, or its times may not be
set.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-utime.actime"></a>`actime` | `Time.time` |  |
| <a name="fld-utime.modtime"></a>`modtime` | `Time.time` |  |

<details><summary>Tests (6)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `actime` &middot; `modtime` &middot; `fstat-agrees` &middot; `NONE-sets-mtime-to-now` &middot; `NONE-sets-atime-to-now` &middot; `missing` (raises)

</details>

### <a name="val-ftruncate"></a>`ftruncate`

```sml
val ftruncate : file_desc * Position.int -> unit
```

`ftruncate (fd, n)` makes the file that `fd` is open on `n` bytes long, cutting or extending it.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open for writing, or cannot be
resized.

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `shorter` &middot; `longer` &middot; `zero` &middot; `same` &middot; `size`

</details>

### <a name="val-pathconf"></a>`pathconf`

```sml
val pathconf : string * string -> SysWord.word option
```

`pathconf (p, name)` is `SOME` of the limit `name` for `p`, or `NONE` when it is unbounded.

The names are written without a prefix: `"NAME_MAX"`, `"PATH_MAX"`,
`"LINK_MAX"`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing, or `name` is not a limit the
system knows.

> **Implementation** `Posix.FileSys.pathconf/what-a-check-can-assume`. The
> suite asks that `NAME_MAX` be bounded and lie between 13 and 255, and
> allows `PATH_MAX` and `LINK_MAX` to be unbounded, `PATH_MAX` being at
> most 65535 when it is not.

<details><summary>Tests (6)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `NAME_MAX` &middot; `PATH_MAX` &middot; `LINK_MAX` &middot; `boolean-properties` &middot; `not-a-property` (raises) &middot; `missing-file` (raises)

</details>

### <a name="val-fpathconf"></a>`fpathconf`

```sml
val fpathconf : file_desc * string -> SysWord.word option
```

`fpathconf (fd, name)` is [`pathconf`](#val-pathconf) for the file that `fd` is open on.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `fd` is not open, or `name` is not a limit the
system knows.

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `NAME_MAX-of-the-directory` &middot; `PIPE_BUF-of-a-pipe` &middot; `boolean-property` &middot; `not-a-property` (raises)

</details>

## See also

[`OS_FILE_SYS`](../sig/OS_FILE_SYS.md), [`POSIX_IO`](../sig/POSIX_IO.md), [`POSIX`](../sig/POSIX.md), [`BIT_FLAGS`](../sig/BIT_FLAGS.md), [`TIME`](../sig/TIME.md)

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_file\_sys.sml; do not edit.</sub>
