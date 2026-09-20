# signature OS_FILE_SYS

[The Standard ML Basis Library](../README.md) &rsaquo; **OS_FILE_SYS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 26 entries documented |
| Tests | 175 checks of 23 entries |
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

<details><summary>Tests (6)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `relative-dot` &middot; `two-streams` &middot; `missing-SysErr` (raises) &middot; `file-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link`

</details>

### <a name="val-readdir"></a>`readDir`

```sml
val readDir : dirstream -> string option
```

<details><summary>Tests (5)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `no-current-or-parent-arc` &middot; `subdirectory` &middot; `NONE-at-the-end` &middot; `empty-directory` &middot; `each-name-once`

</details>

### <a name="val-rewinddir"></a>`rewindDir`

```sml
val rewindDir : dirstream -> unit
```

<details><summary>Tests (2)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `after-some` &middot; `after-the-end`

</details>

### <a name="val-closedir"></a>`closeDir`

```sml
val closeDir : dirstream -> unit
```

<details><summary>Tests (4)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `then-readDir-SysErr` (raises) &middot; `then-rewindDir-SysErr` (raises) &middot; `at-the-end-then-readDir-SysErr` (raises) &middot; `twice`

</details>

### <a name="val-chdir"></a>`chDir`

```sml
val chDir : string -> unit
```

<details><summary>Tests (11)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `relative` &middot; `back-to-absolute` &middot; `parent-arc` &middot; `affects-TextIO.openIn` &middot; `affects-TextIO.openOut` &middot; `affects-FileSys` &middot; `missing-SysErr` (raises) &middot; `failure-keeps-the-directory` &middot; `file-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link`

</details>

### <a name="val-getdir"></a>`getDir`

```sml
val getDir : unit -> string
```

<details><summary>Tests (4)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `absolute` &middot; `canonical` &middot; `same-twice` &middot; `is-a-directory`

</details>

### <a name="val-mkdir"></a>`mkDir`

```sml
val mkDir : string -> unit
```

<details><summary>Tests (6)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `creates` &middot; `nested` &middot; `missing-parent-SysErr` (raises) &middot; `exists-SysErr` (raises) &middot; `over-a-file-SysErr` (raises) &middot; `empty-SysErr` (raises)

</details>

### <a name="val-rmdir"></a>`rmDir`

```sml
val rmDir : string -> unit
```

<details><summary>Tests (7)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `not-empty-SysErr` (raises) &middot; `not-empty-kept` &middot; `missing-SysErr` (raises) &middot; `file-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `empty-directory` &middot; `everything`

</details>

### <a name="val-isdir"></a>`isDir`

```sml
val isDir : string -> bool
```

<details><summary>Tests (10)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `directory` &middot; `current-arc` &middot; `root` &middot; `trailing-separator` &middot; `file` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link` &middot; `link-to-a-file` &middot; `dangling-SysErr` (raises)

</details>

### <a name="val-islink"></a>`isLink`

```sml
val isLink : string -> bool
```

<details><summary>Tests (9)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `file` &middot; `directory` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `symbolic-link` &middot; `to-a-directory` &middot; `dangling` &middot; `link-as-directory-component` &middot; `loop`

</details>

### <a name="val-readlink"></a>`readLink`

```sml
val readLink : string -> string
```

<details><summary>Tests (6)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `file-SysErr` (raises) &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `contents` &middot; `dangling` &middot; `link-as-directory-component`

</details>

### <a name="val-fullpath"></a>`fullPath`

```sml
val fullPath : string -> string
```

<details><summary>Tests (15)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `current-arc` &middot; `empty-is-current-arc` &middot; `relative-file` &middot; `arcs-removed` &middot; `trailing-separator` &middot; `absolute-canonical` &middot; `of-fullPath` &middot; `root` &middot; `parent-arc` &middot; `missing-SysErr` (raises) &middot; `missing-directory-SysErr` (raises) &middot; `link` &middot; `link-as-directory-component` &middot; `link-loop-SysErr` (raises) &middot; `dangling-SysErr` (raises)

</details>

### <a name="val-realpath"></a>`realPath`

```sml
val realPath : string -> string
```

<details><summary>Tests (10)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `relative-file` &middot; `arcs-removed` &middot; `current-arc` &middot; `empty` &middot; `parent-arc` &middot; `from-a-subdirectory` &middot; `absolute-is-fullPath` &middot; `missing-SysErr` (raises) &middot; `link` &middot; `link-then-parent-arc`

</details>

### <a name="val-modtime"></a>`modTime`

```sml
val modTime : string -> Time.time
```

<details><summary>Tests (5)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `new-file-is-now` &middot; `writing-updates` &middot; `other-file-unchanged` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises)

</details>

### <a name="val-filesize"></a>`fileSize`

```sml
val fileSize : string -> Position.int
```

<details><summary>Tests (8)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `bytes` &middot; `empty` &middot; `grows` &middot; `large` &middot; `directory` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link`

</details>

### <a name="val-settime"></a>`setTime`

```sml
val setTime : string * Time.time option -> unit
```

<details><summary>Tests (9)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `SOME` &middot; `SOME-again` &middot; `directory` &middot; `NONE-is-now` &middot; `missing-SysErr` (raises) &middot; `missing-NONE-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link` &middot; `access-time`

</details>

### <a name="val-remove"></a>`remove`

```sml
val remove : string -> unit
```

<details><summary>Tests (7)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `file` &middot; `others-kept` &middot; `missing-SysErr` (raises) &middot; `directory-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `directory-kept` &middot; `tmpName-files`

</details>

### <a name="val-rename"></a>`rename`

```sml
val rename : {old : string, new : string} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-rename.old"></a>`old` | `string` |  |
| <a name="fld-rename.new"></a>`new` | `string` |  |

<details><summary>Tests (11)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `moves` &middot; `replaces` &middot; `same-name` &middot; `other-name-of-same-file` &middot; `into-a-subdirectory` &middot; `directory` &middot; `missing-SysErr` (raises) &middot; `missing-directory-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `failure-keeps-old` &middot; `two-names-of-one-file`

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

<details><summary>Tests (15)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `exists` &middot; `directory-exists` &middot; `missing` &middot; `missing-read` &middot; `missing-directory` &middot; `through-a-file` &middot; `conjunction-file` &middot; `conjunction-directory` &middot; `conjunction-missing` &middot; `repeated-mode` &middot; `through-a-link` &middot; `dangling-link` &middot; `conjunction-read-only` &middot; `exists-without-permissions` &middot; `conjunction-without-permissions`

</details>

### <a name="val-tmpname"></a>`tmpName`

```sml
val tmpName : unit -> string
```

<details><summary>Tests (8)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `creates-a-file` &middot; `empty` &middot; `not-a-directory` &middot; `full-pathname` &middot; `readable-and-writable` &middot; `usable` &middot; `unique` &middot; `not-for-other-users`

</details>

### <a name="type-file_id"></a>`file_id`

```sml
eqtype file_id
```

### <a name="val-fileid"></a>`fileId`

```sml
val fileId : string -> file_id
```

<details><summary>Tests (10)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `same-path` &middot; `other-path` &middot; `different-files` &middot; `directory` &middot; `same-file-after-rename` &middot; `new-content-same-file` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `symbolic-link` &middot; `hard-link`

</details>

### <a name="val-hash"></a>`hash`

```sml
val hash : file_id -> word
```

<details><summary>Tests (3)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `same-object` &middot; `spread` &middot; `hard-link`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : file_id * file_id -> order
```

<details><summary>Tests (4)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `EQUAL-iff-equal` &middot; `antisymmetric` &middot; `transitive` &middot; `same-object`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_os\_file\_sys.sml; do not edit.</sub>
