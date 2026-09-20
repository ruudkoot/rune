# signature OS_FILE_SYS

[The Standard ML Basis Library](../README.md) &rsaquo; **OS_FILE_SYS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 26 entries documented |
| Source | [lib/basis/sig\_os\_file\_sys.sml](../../../../lib/basis/sig_os_file_sys.sml) |

## Synopsis

```sml
signature OS_FILE_SYS
structure OS.FileSys : OS_FILE_SYS
```

| Implementation |  | Source |
| --- | --- | --- |
| `OS.FileSys` |  | [lib/basis/os.sml](../../../../lib/basis/os.sml) |

signature OS\_FILE\_SYS, transcribed from
<https://smlfamily.github.io/Basis/os-file-sys.html>

Time.time and Position.int are the types of the top-level structures Time
and Position.

## Interface

<pre>
signature OS_FILE_SYS =
sig
  type <a href="#type-dirstream">dirstream</a>

  val <a href="#val-opendir">openDir</a> : string -&gt; dirstream
  val <a href="#val-readdir">readDir</a> : dirstream -&gt; string option
  val <a href="#val-rewinddir">rewindDir</a> : dirstream -&gt; unit
  val <a href="#val-closedir">closeDir</a> : dirstream -&gt; unit

  val <a href="#val-chdir">chDir</a> : string -&gt; unit
  val <a href="#val-getdir">getDir</a> : unit -&gt; string
  val <a href="#val-mkdir">mkDir</a> : string -&gt; unit
  val <a href="#val-rmdir">rmDir</a> : string -&gt; unit
  val <a href="#val-isdir">isDir</a> : string -&gt; bool
  val <a href="#val-islink">isLink</a> : string -&gt; bool
  val <a href="#val-readlink">readLink</a> : string -&gt; string
  val <a href="#val-fullpath">fullPath</a> : string -&gt; string
  val <a href="#val-realpath">realPath</a> : string -&gt; string
  val <a href="#val-modtime">modTime</a> : string -&gt; Time.time
  val <a href="#val-filesize">fileSize</a> : string -&gt; Position.int
  val <a href="#val-settime">setTime</a> : string * Time.time option -&gt; unit
  val <a href="#val-remove">remove</a> : string -&gt; unit
  val <a href="#val-rename">rename</a> : {<a href="#fld-rename.old">old</a> : string, <a href="#fld-rename.new">new</a> : string} -&gt; unit

  datatype <a href="#type-access_mode">access_mode</a> = <a href="#con-a_read">A_READ</a> | <a href="#con-a_write">A_WRITE</a> | <a href="#con-a_exec">A_EXEC</a>

  val <a href="#val-access">access</a> : string * access_mode list -&gt; bool

  val <a href="#val-tmpname">tmpName</a> : unit -&gt; string

  eqtype <a href="#type-file_id">file_id</a>

  val <a href="#val-fileid">fileId</a> : string -&gt; file_id
  val <a href="#val-hash">hash</a> : file_id -&gt; word
  val <a href="#val-compare">compare</a> : file_id * file_id -&gt; order
end
</pre>

### <a name="type-dirstream"></a>`dirstream`

```sml
type dirstream
```

### <a name="val-opendir"></a>`openDir`

```sml
val openDir : string -> dirstream
```

### <a name="val-readdir"></a>`readDir`

```sml
val readDir : dirstream -> string option
```

### <a name="val-rewinddir"></a>`rewindDir`

```sml
val rewindDir : dirstream -> unit
```

### <a name="val-closedir"></a>`closeDir`

```sml
val closeDir : dirstream -> unit
```

### <a name="val-chdir"></a>`chDir`

```sml
val chDir : string -> unit
```

### <a name="val-getdir"></a>`getDir`

```sml
val getDir : unit -> string
```

### <a name="val-mkdir"></a>`mkDir`

```sml
val mkDir : string -> unit
```

### <a name="val-rmdir"></a>`rmDir`

```sml
val rmDir : string -> unit
```

### <a name="val-isdir"></a>`isDir`

```sml
val isDir : string -> bool
```

### <a name="val-islink"></a>`isLink`

```sml
val isLink : string -> bool
```

### <a name="val-readlink"></a>`readLink`

```sml
val readLink : string -> string
```

### <a name="val-fullpath"></a>`fullPath`

```sml
val fullPath : string -> string
```

### <a name="val-realpath"></a>`realPath`

```sml
val realPath : string -> string
```

### <a name="val-modtime"></a>`modTime`

```sml
val modTime : string -> Time.time
```

### <a name="val-filesize"></a>`fileSize`

```sml
val fileSize : string -> Position.int
```

### <a name="val-settime"></a>`setTime`

```sml
val setTime : string * Time.time option -> unit
```

### <a name="val-remove"></a>`remove`

```sml
val remove : string -> unit
```

### <a name="val-rename"></a>`rename`

```sml
val rename : {old : string, new : string} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-rename.old"></a>`old` | `string` |  |
| <a name="fld-rename.new"></a>`new` | `string` |  |

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

### <a name="val-tmpname"></a>`tmpName`

```sml
val tmpName : unit -> string
```

### <a name="type-file_id"></a>`file_id`

```sml
eqtype file_id
```

### <a name="val-fileid"></a>`fileId`

```sml
val fileId : string -> file_id
```

### <a name="val-hash"></a>`hash`

```sml
val hash : file_id -> word
```

### <a name="val-compare"></a>`compare`

```sml
val compare : file_id * file_id -> order
```

---

<sub>Generated by runedoc from lib/basis/sig\_os\_file\_sys.sml; do not edit.</sub>
