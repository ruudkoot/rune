# signature POSIX_FILE_SYS

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_FILE_SYS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 91 entries documented |
| Tests | 196 checks of 78 entries |
| Source | [lib/basis/sig\_posix\_file\_sys.sml](../../../../lib/basis/sig_posix_file_sys.sml) |

## Synopsis

```sml
signature POSIX_FILE_SYS
structure Posix.FileSys : POSIX_FILE_SYS
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.FileSys` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

signature POSIX\_FILE\_SYS, transcribed from
<https://smlfamily.github.io/Basis/posix-file-sys.html>

Uses BIT\_FLAGS (spec-sigs/BIT\_FLAGS.sml), which has to be loaded
first: the substructures S and O include BIT\_FLAGS.

The types are kept as the interface writes them. What the text says of
them is not written into the signature: uid and gid are "identical to"
Posix.ProcEnv.uid and gid, and file\_desc is Posix.ProcEnv.file\_desc (the
constraints of `structure FileSys : POSIX_FILE_SYS` in signature POSIX),
dirstream is "identical to OS.FileSys.dirstream" and access\_mode to
OS.FileSys.access\_mode; posix\_filesys\_sig.sml checks those identities.

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

  datatype <a href="#type-access_mode">access_mode</a> = <a href="#con-a_read">A_READ</a> | <a href="#con-a_write">A_WRITE</a> | <a href="#con-a_exec">A_EXEC</a>

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

### <a name="type-gid"></a>`gid`

```sml
eqtype gid
```

### <a name="type-file_desc"></a>`file_desc`

```sml
eqtype file_desc
```

### <a name="val-fdtoword"></a>`fdToWord`

```sml
val fdToWord : file_desc -> SysWord.word
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `inverts-wordToFD` &middot; `distinct-descriptors`

</details>

### <a name="val-wordtofd"></a>`wordToFD`

```sml
val wordToFD : SysWord.word -> file_desc
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `inverts-fdToWord`

</details>

### <a name="val-fdtoiod"></a>`fdToIOD`

```sml
val fdToIOD : file_desc -> OS.IO.iodesc
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `same-descriptor` &middot; `kind-of-a-file`

</details>

### <a name="val-iodtofd"></a>`iodToFD`

```sml
val iodToFD : OS.IO.iodesc -> file_desc option
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `inverts-fdToIOD` &middot; `stdout` &middot; `descriptor-of-a-stream`

</details>

### <a name="type-dirstream"></a>`dirstream`

```sml
type dirstream
```

### <a name="val-opendir"></a>`opendir`

```sml
val opendir : string -> dirstream
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `positioned-at-first-entry` &middot; `missing` (raises) &middot; `a-file` (raises)

</details>

### <a name="val-readdir"></a>`readdir`

```sml
val readdir : dirstream -> string option
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `entries` &middot; `empty-directory` &middot; `NONE-at-end`

</details>

### <a name="val-rewinddir"></a>`rewinddir`

```sml
val rewinddir : dirstream -> unit
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `reads-again` &middot; `after-one-entry`

</details>

### <a name="val-closedir"></a>`closedir`

```sml
val closedir : dirstream -> unit
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `twice` &middot; `then-opendir-again`

</details>

### <a name="val-chdir"></a>`chdir`

```sml
val chdir : string -> unit
```

<details><summary>Tests (6)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `into-subdirectory` &middot; `relative-names` &middot; `back-up` &middot; `absolute` &middot; `missing` (raises) &middot; `failure-keeps-directory`

</details>

### <a name="val-getcwd"></a>`getcwd`

```sml
val getcwd : unit -> string
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `absolute` &middot; `is-the-directory`

</details>

### <a name="val-stdin"></a>`stdin`

```sml
val stdin : file_desc
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-0` &middot; `wordToFD-0`

</details>

### <a name="val-stdout"></a>`stdout`

```sml
val stdout : file_desc
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-1` &middot; `is-open`

</details>

### <a name="val-stderr"></a>`stderr`

```sml
val stderr : file_desc
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-2` &middot; `dup`

</details>

### <a name="str-s"></a>`S`

#### <a name="type-s.mode"></a>`mode`

```sml
eqtype mode
```

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS
  where type flags = mode`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype |  |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val |  |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val |  |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val |  |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val |  |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val |  |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val |  |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val |  |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val |  |

#### <a name="val-s.irwxu"></a>`irwxu`

```sml
val irwxu : mode
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-irusr-iwusr-ixusr` &middot; `chmod`

</details>

#### <a name="val-s.irusr"></a>`irusr`

```sml
val irusr : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.iwusr"></a>`iwusr`

```sml
val iwusr : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.ixusr"></a>`ixusr`

```sml
val ixusr : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.irwxg"></a>`irwxg`

```sml
val irwxg : mode
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-irgrp-iwgrp-ixgrp` &middot; `chmod`

</details>

#### <a name="val-s.irgrp"></a>`irgrp`

```sml
val irgrp : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.iwgrp"></a>`iwgrp`

```sml
val iwgrp : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.ixgrp"></a>`ixgrp`

```sml
val ixgrp : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.irwxo"></a>`irwxo`

```sml
val irwxo : mode
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `is-iroth-iwoth-ixoth` &middot; `chmod`

</details>

#### <a name="val-s.iroth"></a>`iroth`

```sml
val iroth : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.iwoth"></a>`iwoth`

```sml
val iwoth : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.ixoth"></a>`ixoth`

```sml
val ixoth : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

#### <a name="val-s.isuid"></a>`isuid`

```sml
val isuid : mode
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `distinct-from-the-others` &middot; `chmod`

</details>

#### <a name="val-s.isgid"></a>`isgid`

```sml
val isgid : mode
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `chmod`

</details>

### <a name="str-o"></a>`O`

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype |  |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val |  |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val |  |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val |  |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val |  |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val |  |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val |  |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val |  |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val |  |

#### <a name="val-o.append"></a>`append`

```sml
val append : flags
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `writes-at-end`

</details>

#### <a name="val-o.excl"></a>`excl`

```sml
val excl : flags
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `existing-file` (raises) &middot; `new-file`

</details>

#### <a name="val-o.noctty"></a>`noctty`

```sml
val noctty : flags
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `regular-file`

</details>

#### <a name="val-o.nonblock"></a>`nonblock`

```sml
val nonblock : flags
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `regular-file` &middot; `fifo-opens-at-once` &middot; `fifo-without-reader` (raises)

</details>

#### <a name="val-o.sync"></a>`sync`

```sml
val sync : flags
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `writes`

</details>

#### <a name="val-o.trunc"></a>`trunc`

```sml
val trunc : flags
```

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

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-o_rdonly"></a>`O_RDONLY` |  |  |
| <a name="con-o_wronly"></a>`O_WRONLY` |  |  |
| <a name="con-o_rdwr"></a>`O_RDWR` |  |  |

### <a name="val-openf"></a>`openf`

```sml
val openf : string * open_mode * O.flags -> file_desc
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `missing-file` (raises) &middot; `reads-the-file` &middot; `keeps-contents`

</details>

### <a name="val-createf"></a>`createf`

```sml
val createf : string * open_mode * O.flags * S.mode
              -> file_desc
```

<details><summary>Tests (6)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `mode-less-umask` &middot; `mode-with-empty-umask` &middot; `open-mode` &middot; `existing-file` &middot; `existing-mode-kept` &middot; `with-trunc`

</details>

### <a name="val-creat"></a>`creat`

```sml
val creat : string * S.mode -> file_desc
```

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `truncates` &middot; `mode-less-umask` &middot; `writes` &middot; `write-only` (raises)

</details>

### <a name="val-umask"></a>`umask`

```sml
val umask : S.mode -> S.mode
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `returns-previous` &middot; `set-then-read` &middot; `removes-permissions`

</details>

### <a name="val-link"></a>`link`

```sml
val link : {old : string, new : string} -> unit
```

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

<details><summary>Tests (7)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `makes-a-directory` &middot; `mode` &middot; `mode-less-umask` &middot; `owner-only` &middot; `mask-unchanged` &middot; `existing` (raises) &middot; `missing-parent` (raises)

</details>

### <a name="val-mkfifo"></a>`mkfifo`

```sml
val mkfifo : string * S.mode -> unit
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `makes-a-fifo` &middot; `mode-less-umask` &middot; `existing` (raises)

</details>

### <a name="val-unlink"></a>`unlink`

```sml
val unlink : string -> unit
```

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `removes` &middot; `decrements-link-count` &middot; `symbolic-link` &middot; `open-file` &middot; `missing` (raises)

</details>

### <a name="val-rmdir"></a>`rmdir`

```sml
val rmdir : string -> unit
```

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `removes` &middot; `not-empty` (raises) &middot; `a-file` (raises) &middot; `missing` (raises)

</details>

### <a name="val-rename"></a>`rename`

```sml
val rename : {old : string, new : string} -> unit
```

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

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_dir.sml](../../../../tests/basis/posix_filesys_dir.sml): `text-of-the-link` &middot; `relative-path-kept` &middot; `absolute-path` &middot; `not-a-link` (raises) &middot; `missing` (raises)

</details>

### <a name="type-dev"></a>`dev`

```sml
eqtype dev
```

### <a name="val-wordtodev"></a>`wordToDev`

```sml
val wordToDev : SysWord.word -> dev
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `inverts-devToWord`

</details>

### <a name="val-devtoword"></a>`devToWord`

```sml
val devToWord : dev -> SysWord.word
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `inverts-wordToDev` &middot; `same-device`

</details>

### <a name="type-ino"></a>`ino`

```sml
eqtype ino
```

### <a name="val-wordtoino"></a>`wordToIno`

```sml
val wordToIno : SysWord.word -> ino
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `inverts-inoToWord`

</details>

### <a name="val-inotoword"></a>`inoToWord`

```sml
val inoToWord : ino -> SysWord.word
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `inverts-wordToIno` &middot; `distinct-files`

</details>

### <a name="str-st"></a>`ST`

#### <a name="type-st.stat"></a>`stat`

```sml
type stat
```

#### <a name="val-st.isdir"></a>`isDir`

```sml
val isDir : stat -> bool
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `directory` &middot; `current-directory`

</details>

#### <a name="val-st.ischr"></a>`isChr`

```sml
val isChr : stat -> bool
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `dev-null`

</details>

#### <a name="val-st.isblk"></a>`isBlk`

```sml
val isBlk : stat -> bool
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `none-of-the-others`

</details>

#### <a name="val-st.isreg"></a>`isReg`

```sml
val isReg : stat -> bool
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `regular-file`

</details>

#### <a name="val-st.isfifo"></a>`isFIFO`

```sml
val isFIFO : stat -> bool
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `mkfifo` &middot; `pipe`

</details>

#### <a name="val-st.islink"></a>`isLink`

```sml
val isLink : stat -> bool
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `lstat-of-a-link` &middot; `dangling-link`

</details>

#### <a name="val-st.issock"></a>`isSock`

```sml
val isSock : stat -> bool
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `none-of-the-others` &middot; `socket`

</details>

#### <a name="val-st.mode"></a>`mode`

```sml
val mode : stat -> S.mode
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `regular-file` &middot; `directory` &middot; `fifo`

</details>

#### <a name="val-st.ino"></a>`ino`

```sml
val ino : stat -> ino
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `distinct-files` &middot; `same-file`

</details>

#### <a name="val-st.dev"></a>`dev`

```sml
val dev : stat -> dev
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `same-directory`

</details>

#### <a name="val-st.nlink"></a>`nlink`

```sml
val nlink : stat -> int
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `new-file` &middot; `three-links`

</details>

#### <a name="val-st.uid"></a>`uid`

```sml
val uid : stat -> uid
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `new-file`

</details>

#### <a name="val-st.gid"></a>`gid`

```sml
val gid : stat -> gid
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `new-file`

</details>

#### <a name="val-st.size"></a>`size`

```sml
val size : stat -> Position.int
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `bytes` &middot; `empty` &middot; `lstat-of-a-link-is-its-text`

</details>

#### <a name="val-st.atime"></a>`atime`

```sml
val atime : stat -> Time.time
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `utime`

</details>

#### <a name="val-st.mtime"></a>`mtime`

```sml
val mtime : stat -> Time.time
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `utime` &middot; `new-file`

</details>

#### <a name="val-st.ctime"></a>`ctime`

```sml
val ctime : stat -> Time.time
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `after-utime`

</details>

### <a name="val-stat"></a>`stat`

```sml
val stat : string -> ST.stat
```

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `empty-string` (raises) &middot; `missing` (raises) &middot; `follows-a-link` &middot; `dangling-link` (raises)

</details>

### <a name="val-lstat"></a>`lstat`

```sml
val lstat : string -> ST.stat
```

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `empty-string` (raises) &middot; `missing` (raises) &middot; `regular-file` &middot; `the-link-itself`

</details>

### <a name="val-fstat"></a>`fstat`

```sml
val fstat : file_desc -> ST.stat
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `same-file` &middot; `kind` &middot; `directory`

</details>

### <a name="type-access_mode"></a>`access_mode`

```sml
datatype access_mode = A_READ | A_WRITE | A_EXEC
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-a_read"></a>`A_READ` |  |  |
| <a name="con-a_write"></a>`A_WRITE` |  |  |
| <a name="con-a_exec"></a>`A_EXEC` |  |  |

### <a name="val-access"></a>`access`

```sml
val access : string * access_mode list -> bool
```

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `exists` &middot; `missing` &middot; `missing-read` &middot; `every-mode-of-the-list` &middot; `directory`

</details>

### <a name="val-chmod"></a>`chmod`

```sml
val chmod : string * S.mode -> unit
```

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `sets-mode` &middot; `not-masked` &middot; `no-permissions` &middot; `missing-file` (raises) &middot; `empty-path` (raises)

</details>

### <a name="val-fchmod"></a>`fchmod`

```sml
val fchmod : file_desc * S.mode -> unit
```

<details><summary>Tests (2)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `sets-mode` &middot; `fstat-agrees`

</details>

### <a name="val-chown"></a>`chown`

```sml
val chown : string * uid * gid -> unit
```

<details><summary>Tests (3)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `to-current-owner` &middot; `owner-is-process` &middot; `missing-file` (raises)

</details>

### <a name="val-fchown"></a>`fchown`

```sml
val fchown : file_desc * uid * gid -> unit
```

<details><summary>Tests (1)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `to-current-owner`

</details>

### <a name="val-utime"></a>`utime`

```sml
val utime : string
            * {actime : Time.time, modtime : Time.time} option
            -> unit
```

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

<details><summary>Tests (5)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `shorter` &middot; `longer` &middot; `zero` &middot; `same` &middot; `size`

</details>

### <a name="val-pathconf"></a>`pathconf`

```sml
val pathconf : string * string -> SysWord.word option
```

<details><summary>Tests (6)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `NAME_MAX` &middot; `PATH_MAX` &middot; `LINK_MAX` &middot; `boolean-properties` &middot; `not-a-property` (raises) &middot; `missing-file` (raises)

</details>

### <a name="val-fpathconf"></a>`fpathconf`

```sml
val fpathconf : file_desc * string -> SysWord.word option
```

<details><summary>Tests (4)</summary>

For `Posix.FileSys`, in [tests/basis/posix\_filesys\_stat.sml](../../../../tests/basis/posix_filesys_stat.sml): `NAME_MAX-of-the-directory` &middot; `PIPE_BUF-of-a-pipe` &middot; `boolean-property` &middot; `not-a-property` (raises)

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_file\_sys.sml; do not edit.</sub>
