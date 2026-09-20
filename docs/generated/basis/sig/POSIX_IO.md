# signature POSIX_IO

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 41 entries documented |
| Source | [lib/basis/sig\_posix\_io.sml](../../../../lib/basis/sig_posix_io.sml) |

## Synopsis

```sml
signature POSIX_IO
structure Posix.IO : POSIX_IO
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.IO` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

signature POSIX\_IO, transcribed from
<https://smlfamily.github.io/Basis/posix-io.html>

Uses BIT\_FLAGS (spec-sigs/BIT\_FLAGS.sml), which has to be loaded
first: the substructures FD and O include BIT\_FLAGS.

The types are kept as the interface writes them. The constraints of
`structure IO : POSIX_IO` in signature POSIX (pid is Posix.Process.pid,
file\_desc is Posix.ProcEnv.file\_desc, open\_mode is Posix.FileSys.open\_mode)
are not written into the signature; posix\_io\_sig.sml checks them.

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

### <a name="type-pid"></a>`pid`

```sml
eqtype pid
```

### <a name="val-pipe"></a>`pipe`

```sml
val pipe : unit -> {infd : file_desc, outfd : file_desc}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-pipe.infd"></a>`infd` | `file_desc` |  |
| <a name="fld-pipe.outfd"></a>`outfd` | `file_desc` |  |

### <a name="val-dup"></a>`dup`

```sml
val dup : file_desc -> file_desc
```

### <a name="val-dup2"></a>`dup2`

```sml
val dup2 : {old : file_desc, new : file_desc} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-dup2.old"></a>`old` | `file_desc` |  |
| <a name="fld-dup2.new"></a>`new` | `file_desc` |  |

### <a name="val-close"></a>`close`

```sml
val close : file_desc -> unit
```

### <a name="val-readvec"></a>`readVec`

```sml
val readVec : file_desc * int -> Word8Vector.vector
```

### <a name="val-readarr"></a>`readArr`

```sml
val readArr : file_desc * Word8ArraySlice.slice -> int
```

### <a name="val-writevec"></a>`writeVec`

```sml
val writeVec : file_desc * Word8VectorSlice.slice -> int
```

### <a name="val-writearr"></a>`writeArr`

```sml
val writeArr : file_desc * Word8ArraySlice.slice -> int
```

### <a name="type-whence"></a>`whence`

```sml
datatype whence
  = SEEK_SET
  | SEEK_CUR
  | SEEK_END
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-seek_set"></a>`SEEK_SET` |  |  |
| <a name="con-seek_cur"></a>`SEEK_CUR` |  |  |
| <a name="con-seek_end"></a>`SEEK_END` |  |  |

### <a name="str-fd"></a>`FD`

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

#### <a name="val-fd.cloexec"></a>`cloexec`

```sml
val cloexec : flags
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

#### <a name="val-o.nonblock"></a>`nonblock`

```sml
val nonblock : flags
```

#### <a name="val-o.sync"></a>`sync`

```sml
val sync : flags
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

### <a name="val-dupfd"></a>`dupfd`

```sml
val dupfd : {old : file_desc, base : file_desc}
            -> file_desc
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-dupfd.old"></a>`old` | `file_desc` |  |
| <a name="fld-dupfd.base"></a>`base` | `file_desc` |  |

### <a name="val-getfd"></a>`getfd`

```sml
val getfd : file_desc -> FD.flags
```

### <a name="val-setfd"></a>`setfd`

```sml
val setfd : file_desc * FD.flags -> unit
```

### <a name="val-getfl"></a>`getfl`

```sml
val getfl : file_desc -> O.flags * open_mode
```

### <a name="val-setfl"></a>`setfl`

```sml
val setfl : file_desc * O.flags -> unit
```

### <a name="val-lseek"></a>`lseek`

```sml
val lseek : file_desc * Position.int * whence
            -> Position.int
```

### <a name="val-fsync"></a>`fsync`

```sml
val fsync : file_desc -> unit
```

### <a name="type-lock_type"></a>`lock_type`

```sml
datatype lock_type
  = F_RDLCK
  | F_WRLCK
  | F_UNLCK
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-f_rdlck"></a>`F_RDLCK` |  |  |
| <a name="con-f_wrlck"></a>`F_WRLCK` |  |  |
| <a name="con-f_unlck"></a>`F_UNLCK` |  |  |

### <a name="str-flock"></a>`FLock`

#### <a name="type-flock.flock"></a>`flock`

```sml
type flock
```

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

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-flock.flock.ltype"></a>`ltype` | `lock_type` |  |
| <a name="fld-flock.flock.whence"></a>`whence` | `whence` |  |
| <a name="fld-flock.flock.start"></a>`start` | `Position.int` |  |
| <a name="fld-flock.flock.len"></a>`len` | `Position.int` |  |
| <a name="fld-flock.flock.pid"></a>`pid` | `pid option` |  |

#### <a name="val-flock.ltype"></a>`ltype`

```sml
val ltype : flock -> lock_type
```

#### <a name="val-flock.whence"></a>`whence`

```sml
val whence : flock -> whence
```

#### <a name="val-flock.start"></a>`start`

```sml
val start : flock -> Position.int
```

#### <a name="val-flock.len"></a>`len`

```sml
val len : flock -> Position.int
```

#### <a name="val-flock.pid"></a>`pid`

```sml
val pid : flock -> pid option
```

### <a name="val-getlk"></a>`getlk`

```sml
val getlk : file_desc * FLock.flock -> FLock.flock
```

### <a name="val-setlk"></a>`setlk`

```sml
val setlk : file_desc * FLock.flock -> FLock.flock
```

### <a name="val-setlkw"></a>`setlkw`

```sml
val setlkw : file_desc * FLock.flock -> FLock.flock
```

### <a name="val-mkbinreader"></a>`mkBinReader`

```sml
val mkBinReader : {
                    fd : file_desc,
                    name : string,
                    initBlkMode : bool
                  } -> BinPrimIO.reader
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mkbinreader.fd"></a>`fd` | `file_desc` |  |
| <a name="fld-mkbinreader.name"></a>`name` | `string` |  |
| <a name="fld-mkbinreader.initblkmode"></a>`initBlkMode` | `bool` |  |

### <a name="val-mktextreader"></a>`mkTextReader`

```sml
val mkTextReader : {
                     fd : file_desc,
                     name : string,
                     initBlkMode : bool
                   } -> TextPrimIO.reader
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mktextreader.fd"></a>`fd` | `file_desc` |  |
| <a name="fld-mktextreader.name"></a>`name` | `string` |  |
| <a name="fld-mktextreader.initblkmode"></a>`initBlkMode` | `bool` |  |

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

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mkbinwriter.fd"></a>`fd` | `file_desc` |  |
| <a name="fld-mkbinwriter.name"></a>`name` | `string` |  |
| <a name="fld-mkbinwriter.appendmode"></a>`appendMode` | `bool` |  |
| <a name="fld-mkbinwriter.initblkmode"></a>`initBlkMode` | `bool` |  |
| <a name="fld-mkbinwriter.chunksize"></a>`chunkSize` | `int` |  |

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

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mktextwriter.fd"></a>`fd` | `file_desc` |  |
| <a name="fld-mktextwriter.name"></a>`name` | `string` |  |
| <a name="fld-mktextwriter.appendmode"></a>`appendMode` | `bool` |  |
| <a name="fld-mktextwriter.initblkmode"></a>`initBlkMode` | `bool` |  |
| <a name="fld-mktextwriter.chunksize"></a>`chunkSize` | `int` |  |

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_io.sml; do not edit.</sub>
