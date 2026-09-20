# signature POSIX_FILE_SYS

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_FILE_SYS**

|  |  |
| --- | --- |
| Status | required |
| Documentation | 0 of 91 entries documented |
| Source | [lib/basis/sig\_posix\_file\_sys.sml](../../../../lib/basis/sig_posix_file_sys.sml) |

## Synopsis

```sml
signature POSIX_FILE_SYS
```

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

### <a name="val-wordtofd"></a>`wordToFD`

```sml
val wordToFD : SysWord.word -> file_desc
```

### <a name="val-fdtoiod"></a>`fdToIOD`

```sml
val fdToIOD : file_desc -> OS.IO.iodesc
```

### <a name="val-iodtofd"></a>`iodToFD`

```sml
val iodToFD : OS.IO.iodesc -> file_desc option
```

### <a name="type-dirstream"></a>`dirstream`

```sml
type dirstream
```

### <a name="val-opendir"></a>`opendir`

```sml
val opendir : string -> dirstream
```

### <a name="val-readdir"></a>`readdir`

```sml
val readdir : dirstream -> string option
```

### <a name="val-rewinddir"></a>`rewinddir`

```sml
val rewinddir : dirstream -> unit
```

### <a name="val-closedir"></a>`closedir`

```sml
val closedir : dirstream -> unit
```

### <a name="val-chdir"></a>`chdir`

```sml
val chdir : string -> unit
```

### <a name="val-getcwd"></a>`getcwd`

```sml
val getcwd : unit -> string
```

### <a name="val-stdin"></a>`stdin`

```sml
val stdin : file_desc
```

### <a name="val-stdout"></a>`stdout`

```sml
val stdout : file_desc
```

### <a name="val-stderr"></a>`stderr`

```sml
val stderr : file_desc
```

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

#### <a name="val-s.irusr"></a>`irusr`

```sml
val irusr : mode
```

#### <a name="val-s.iwusr"></a>`iwusr`

```sml
val iwusr : mode
```

#### <a name="val-s.ixusr"></a>`ixusr`

```sml
val ixusr : mode
```

#### <a name="val-s.irwxg"></a>`irwxg`

```sml
val irwxg : mode
```

#### <a name="val-s.irgrp"></a>`irgrp`

```sml
val irgrp : mode
```

#### <a name="val-s.iwgrp"></a>`iwgrp`

```sml
val iwgrp : mode
```

#### <a name="val-s.ixgrp"></a>`ixgrp`

```sml
val ixgrp : mode
```

#### <a name="val-s.irwxo"></a>`irwxo`

```sml
val irwxo : mode
```

#### <a name="val-s.iroth"></a>`iroth`

```sml
val iroth : mode
```

#### <a name="val-s.iwoth"></a>`iwoth`

```sml
val iwoth : mode
```

#### <a name="val-s.ixoth"></a>`ixoth`

```sml
val ixoth : mode
```

#### <a name="val-s.isuid"></a>`isuid`

```sml
val isuid : mode
```

#### <a name="val-s.isgid"></a>`isgid`

```sml
val isgid : mode
```

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

#### <a name="val-o.excl"></a>`excl`

```sml
val excl : flags
```

#### <a name="val-o.noctty"></a>`noctty`

```sml
val noctty : flags
```

#### <a name="val-o.nonblock"></a>`nonblock`

```sml
val nonblock : flags
```

#### <a name="val-o.sync"></a>`sync`

```sml
val sync : flags
```

#### <a name="val-o.trunc"></a>`trunc`

```sml
val trunc : flags
```

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

### <a name="val-createf"></a>`createf`

```sml
val createf : string * open_mode * O.flags * S.mode
              -> file_desc
```

### <a name="val-creat"></a>`creat`

```sml
val creat : string * S.mode -> file_desc
```

### <a name="val-umask"></a>`umask`

```sml
val umask : S.mode -> S.mode
```

### <a name="val-link"></a>`link`

```sml
val link : {old : string, new : string} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-link.old"></a>`old` | `string` |  |
| <a name="fld-link.new"></a>`new` | `string` |  |

### <a name="val-mkdir"></a>`mkdir`

```sml
val mkdir : string * S.mode -> unit
```

### <a name="val-mkfifo"></a>`mkfifo`

```sml
val mkfifo : string * S.mode -> unit
```

### <a name="val-unlink"></a>`unlink`

```sml
val unlink : string -> unit
```

### <a name="val-rmdir"></a>`rmdir`

```sml
val rmdir : string -> unit
```

### <a name="val-rename"></a>`rename`

```sml
val rename : {old : string, new : string} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-rename.old"></a>`old` | `string` |  |
| <a name="fld-rename.new"></a>`new` | `string` |  |

### <a name="val-symlink"></a>`symlink`

```sml
val symlink : {old : string, new : string} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-symlink.old"></a>`old` | `string` |  |
| <a name="fld-symlink.new"></a>`new` | `string` |  |

### <a name="val-readlink"></a>`readlink`

```sml
val readlink : string -> string
```

### <a name="type-dev"></a>`dev`

```sml
eqtype dev
```

### <a name="val-wordtodev"></a>`wordToDev`

```sml
val wordToDev : SysWord.word -> dev
```

### <a name="val-devtoword"></a>`devToWord`

```sml
val devToWord : dev -> SysWord.word
```

### <a name="type-ino"></a>`ino`

```sml
eqtype ino
```

### <a name="val-wordtoino"></a>`wordToIno`

```sml
val wordToIno : SysWord.word -> ino
```

### <a name="val-inotoword"></a>`inoToWord`

```sml
val inoToWord : ino -> SysWord.word
```

### <a name="str-st"></a>`ST`

#### <a name="type-st.stat"></a>`stat`

```sml
type stat
```

#### <a name="val-st.isdir"></a>`isDir`

```sml
val isDir : stat -> bool
```

#### <a name="val-st.ischr"></a>`isChr`

```sml
val isChr : stat -> bool
```

#### <a name="val-st.isblk"></a>`isBlk`

```sml
val isBlk : stat -> bool
```

#### <a name="val-st.isreg"></a>`isReg`

```sml
val isReg : stat -> bool
```

#### <a name="val-st.isfifo"></a>`isFIFO`

```sml
val isFIFO : stat -> bool
```

#### <a name="val-st.islink"></a>`isLink`

```sml
val isLink : stat -> bool
```

#### <a name="val-st.issock"></a>`isSock`

```sml
val isSock : stat -> bool
```

#### <a name="val-st.mode"></a>`mode`

```sml
val mode : stat -> S.mode
```

#### <a name="val-st.ino"></a>`ino`

```sml
val ino : stat -> ino
```

#### <a name="val-st.dev"></a>`dev`

```sml
val dev : stat -> dev
```

#### <a name="val-st.nlink"></a>`nlink`

```sml
val nlink : stat -> int
```

#### <a name="val-st.uid"></a>`uid`

```sml
val uid : stat -> uid
```

#### <a name="val-st.gid"></a>`gid`

```sml
val gid : stat -> gid
```

#### <a name="val-st.size"></a>`size`

```sml
val size : stat -> Position.int
```

#### <a name="val-st.atime"></a>`atime`

```sml
val atime : stat -> Time.time
```

#### <a name="val-st.mtime"></a>`mtime`

```sml
val mtime : stat -> Time.time
```

#### <a name="val-st.ctime"></a>`ctime`

```sml
val ctime : stat -> Time.time
```

### <a name="val-stat"></a>`stat`

```sml
val stat : string -> ST.stat
```

### <a name="val-lstat"></a>`lstat`

```sml
val lstat : string -> ST.stat
```

### <a name="val-fstat"></a>`fstat`

```sml
val fstat : file_desc -> ST.stat
```

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

### <a name="val-chmod"></a>`chmod`

```sml
val chmod : string * S.mode -> unit
```

### <a name="val-fchmod"></a>`fchmod`

```sml
val fchmod : file_desc * S.mode -> unit
```

### <a name="val-chown"></a>`chown`

```sml
val chown : string * uid * gid -> unit
```

### <a name="val-fchown"></a>`fchown`

```sml
val fchown : file_desc * uid * gid -> unit
```

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

### <a name="val-ftruncate"></a>`ftruncate`

```sml
val ftruncate : file_desc * Position.int -> unit
```

### <a name="val-pathconf"></a>`pathconf`

```sml
val pathconf : string * string -> SysWord.word option
```

### <a name="val-fpathconf"></a>`fpathconf`

```sml
val fpathconf : file_desc * string -> SysWord.word option
```

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_file\_sys.sml; do not edit.</sub>
