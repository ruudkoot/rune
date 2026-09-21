# signature OS_FILE_SYS

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **OS_FILE_SYS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 26 of 26 entries documented |
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

The file system: reading directories, moving about in them, and asking
what a file is and when it changed.

Where [`OS_PATH`](../sig/OS_PATH.md) works on the text of a path alone, everything here touches
the file system, and everything here reports a refusal the same way:
[`OS.SysErr`](../sig/OS.md#exn-syserr) with the message and the condition the system gave. A path
that names nothing, a directory that may not be read, a file that may not
be removed -- all of them arrive as that one exception.

A directory is read as a stream: [`openDir`](#val-opendir), then [`readDir`](#val-readdir) until it gives
`NONE`, then [`closeDir`](#val-closedir). The names it gives are arcs, not paths, and
`"."` and `".."` are not among them.

> **Implementation** `OS.FileSys/errors-are-SysErr`. Every failure raises
> [`OS.SysErr`](../sig/OS.md#exn-syserr) carrying the reason the system gave; no operation here has an
> exception of its own.

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

  datatype <a href="#type-access_mode">access_mode</a>
    = <a href="#con-a_read">A_READ</a>
    | <a href="#con-a_write">A_WRITE</a>
    | <a href="#con-a_exec">A_EXEC</a>

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

The type of an open directory being read.

### <a name="val-opendir"></a>`openDir`

```sml
val openDir : string -> dirstream
```

`openDir p` opens the directory `p` for reading.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is no directory, or may not be read.

<details><summary>Tests (6)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `relative-dot` &middot; `two-streams` &middot; `missing-SysErr` (raises) &middot; `file-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link`

</details>

### <a name="val-readdir"></a>`readDir`

```sml
val readDir : dirstream -> string option
```

`readDir d` is `SOME` of the next name in `d`, or `NONE` when there are no more.

The names are arcs of the directory, in no particular order, and
[`OS.Path.currentArc`](../sig/OS_PATH.md#val-currentarc) and [`OS.Path.parentArc`](../sig/OS_PATH.md#val-parentarc) are not among them.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the directory cannot be read.

> **Reading** `OS.FileSys.readDir/empty-stays-empty`. Once the stream is
> spent it stays spent: [`readDir`](#val-readdir) keeps giving `NONE` however often it is
> called, until [`rewindDir`](#val-rewinddir).

<details><summary>Tests (5)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `no-current-or-parent-arc` &middot; `subdirectory` &middot; `NONE-at-the-end` &middot; `empty-directory` &middot; `each-name-once`

</details>

### <a name="val-rewinddir"></a>`rewindDir`

```sml
val rewindDir : dirstream -> unit
```

`rewindDir d` puts `d` back at its first name.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the directory cannot be read again.

<details><summary>Tests (2)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `after-some` &middot; `after-the-end`

</details>

### <a name="val-closedir"></a>`closeDir`

```sml
val closeDir : dirstream -> unit
```

`closeDir d` closes `d`; closing twice is allowed.

<details><summary>Tests (4)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `then-readDir-SysErr` (raises) &middot; `then-rewindDir-SysErr` (raises) &middot; `at-the-end-then-readDir-SysErr` (raises) &middot; `twice`

</details>

### <a name="val-chdir"></a>`chDir`

```sml
val chDir : string -> unit
```

`chDir p` makes `p` the current directory of the process.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is no directory, or may not be entered.

<details><summary>Tests (11)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `relative` &middot; `back-to-absolute` &middot; `parent-arc` &middot; `affects-TextIO.openIn` &middot; `affects-TextIO.openOut` &middot; `affects-FileSys` &middot; `missing-SysErr` (raises) &middot; `failure-keeps-the-directory` &middot; `file-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link`

</details>

### <a name="val-getdir"></a>`getDir`

```sml
val getDir : unit -> string
```

`getDir ()` is the current directory, as an absolute canonical path.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if it cannot be found.

<details><summary>Tests (4)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `absolute` &middot; `canonical` &middot; `same-twice` &middot; `is-a-directory`

</details>

### <a name="val-mkdir"></a>`mkDir`

```sml
val mkDir : string -> unit
```

`mkDir p` makes a directory `p`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is there already, or cannot be made.

> **Implementation** `OS.FileSys.mkDir/mode`. The directory gets every
> permission that the mask of the process leaves, as [`Posix.FileSys.mkdir`](../sig/POSIX_FILE_SYS.md#val-mkdir)
> with the mode 0777 would give it.

<details><summary>Tests (6)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `creates` &middot; `nested` &middot; `missing-parent-SysErr` (raises) &middot; `exists-SysErr` (raises) &middot; `over-a-file-SysErr` (raises) &middot; `empty-SysErr` (raises)

</details>

### <a name="val-rmdir"></a>`rmDir`

```sml
val rmDir : string -> unit
```

`rmDir p` removes the directory `p`, which must be empty.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is not an empty directory, or may not be
removed.

<details><summary>Tests (7)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `not-empty-SysErr` (raises) &middot; `not-empty-kept` &middot; `missing-SysErr` (raises) &middot; `file-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `empty-directory` &middot; `everything`

</details>

### <a name="val-isdir"></a>`isDir`

```sml
val isDir : string -> bool
```

`isDir p` is `true` when `p` names a directory, following symbolic links.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing.

**Example** `isDir "." = true`

<details><summary>Tests (10)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `directory` &middot; `current-arc` &middot; `root` &middot; `trailing-separator` &middot; `file` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link` &middot; `link-to-a-file` &middot; `dangling-SysErr` (raises)

</details>

### <a name="val-islink"></a>`isLink`

```sml
val isLink : string -> bool
```

`isLink p` is `true` when `p` itself is a symbolic link, without following it.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing.

<details><summary>Tests (9)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `file` &middot; `directory` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `symbolic-link` &middot; `to-a-directory` &middot; `dangling` &middot; `link-as-directory-component` &middot; `loop`

</details>

### <a name="val-readlink"></a>`readLink`

```sml
val readLink : string -> string
```

`readLink p` is the path that the symbolic link `p` holds, as it is written there.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` is no symbolic link.

<details><summary>Tests (6)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `file-SysErr` (raises) &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `contents` &middot; `dangling` &middot; `link-as-directory-component`

</details>

### <a name="val-fullpath"></a>`fullPath`

```sml
val fullPath : string -> string
```

`fullPath p` is `p` as an absolute canonical path, with every symbolic link followed.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing, or a link leads nowhere or in a
circle.

**Example** `fullPath "." = getDir ()`

<details><summary>Tests (15)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `current-arc` &middot; `empty-is-current-arc` &middot; `relative-file` &middot; `arcs-removed` &middot; `trailing-separator` &middot; `absolute-canonical` &middot; `of-fullPath` &middot; `root` &middot; `parent-arc` &middot; `missing-SysErr` (raises) &middot; `missing-directory-SysErr` (raises) &middot; `link` &middot; `link-as-directory-component` &middot; `link-loop-SysErr` (raises) &middot; `dangling-SysErr` (raises)

</details>

### <a name="val-realpath"></a>`realPath`

```sml
val realPath : string -> string
```

`realPath p` is `fullPath p` when `p` is absolute, and the same made relative to the current directory when it is not.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) as [`fullPath`](#val-fullpath) does.

<details><summary>Tests (10)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `relative-file` &middot; `arcs-removed` &middot; `current-arc` &middot; `empty` &middot; `parent-arc` &middot; `from-a-subdirectory` &middot; `absolute-is-fullPath` &middot; `missing-SysErr` (raises) &middot; `link` &middot; `link-then-parent-arc`

</details>

### <a name="val-modtime"></a>`modTime`

```sml
val modTime : string -> Time.time
```

`modTime p` is when what `p` names was last changed.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing.

> **Implementation** `OS.FileSys.modTime/whole-seconds`. The VM passes on
> the whole seconds of the time that the file system keeps, so the time
> has no fraction.

<details><summary>Tests (5)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `new-file-is-now` &middot; `writing-updates` &middot; `other-file-unchanged` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises)

</details>

### <a name="val-filesize"></a>`fileSize`

```sml
val fileSize : string -> Position.int
```

`fileSize p` is the size in bytes of what `p` names.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing.

<details><summary>Tests (8)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `bytes` &middot; `empty` &middot; `grows` &middot; `large` &middot; `directory` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link`

</details>

### <a name="val-settime"></a>`setTime`

```sml
val setTime : string * Time.time option -> unit
```

`setTime (p, t)` sets the time of what `p` names to `t`, or to now when `t` is `NONE`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing, or its time may not be set.

> **Implementation** `OS.FileSys.setTime/what-a-check-can-assume`. The range
> of a [`Time.time`](../sig/TIME.md#type-time) is the implementation's, so the suite builds the times
> it sets inside the checks; and because the file system may keep whole
> seconds only, "now" is checked with a second of slack either way.

<details><summary>Tests (9)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `SOME` &middot; `SOME-again` &middot; `directory` &middot; `NONE-is-now` &middot; `missing-SysErr` (raises) &middot; `missing-NONE-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `through-a-link` &middot; `access-time`

</details>

### <a name="val-remove"></a>`remove`

```sml
val remove : string -> unit
```

`remove p` removes the file `p`, which must not be a directory.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing, is a directory, or may not be
removed.

<details><summary>Tests (7)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `file` &middot; `others-kept` &middot; `missing-SysErr` (raises) &middot; `directory-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `directory-kept` &middot; `tmpName-files`

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

<details><summary>Tests (11)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `moves` &middot; `replaces` &middot; `same-name` &middot; `other-name-of-same-file` &middot; `into-a-subdirectory` &middot; `directory` &middot; `missing-SysErr` (raises) &middot; `missing-directory-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `failure-keeps-old` &middot; `two-names-of-one-file`

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

`access (p, modes)` is `true` when the process may do all of `modes` to what `p` names.

An empty list asks only whether `p` names something.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the question cannot be answered -- not when the
answer is no.

> **Implementation** `OS.FileSys.access/depends-on-the-process`. Whether a
> file counts as executable is the system's affair, and a privileged
> process may read and write whatever the permission bits say, so the
> suite's checks of the bits hold only for an ordinary process.

<details><summary>Tests (15)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `exists` &middot; `directory-exists` &middot; `missing` &middot; `missing-read` &middot; `missing-directory` &middot; `through-a-file` &middot; `conjunction-file` &middot; `conjunction-directory` &middot; `conjunction-missing` &middot; `repeated-mode` &middot; `through-a-link` &middot; `dangling-link` &middot; `conjunction-read-only` &middot; `exists-without-permissions` &middot; `conjunction-without-permissions`

</details>

### <a name="val-tmpname"></a>`tmpName`

```sml
val tmpName : unit -> string
```

`tmpName ()` is the path of a file that does not exist yet, for temporary use.

The file is not created, so two processes can still race for the
name.

<details><summary>Tests (8)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `creates-a-file` &middot; `empty` &middot; `not-a-directory` &middot; `full-pathname` &middot; `readable-and-writable` &middot; `usable` &middot; `unique` &middot; `not-for-other-users`

</details>

### <a name="type-file_id"></a>`file_id`

```sml
eqtype file_id
```

The type that tells one file from another, whatever path leads to it.

### <a name="val-fileid"></a>`fileId`

```sml
val fileId : string -> file_id
```

`fileId p` is the identity of what `p` names: two paths to one file give the same [`file_id`](#type-file_id).

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `p` names nothing.

<details><summary>Tests (10)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `same-path` &middot; `other-path` &middot; `different-files` &middot; `directory` &middot; `same-file-after-rename` &middot; `new-content-same-file` &middot; `missing-SysErr` (raises) &middot; `empty-SysErr` (raises) &middot; `symbolic-link` &middot; `hard-link`

</details>

### <a name="val-hash"></a>`hash`

```sml
val hash : file_id -> word
```

`hash id` is a word for `id`, spread well enough to index a table with.

> **Implementation** `OS.FileSys.hash/device-and-inode`. It is the device
> number times 65599 plus the inode number, in wrapping word arithmetic.
> "Well distributed modulo 2^n" is checked only as far as a test can: the
> same file hashes the same, and sixteen files do not all agree in the
> lowest bit.

<details><summary>Tests (3)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `same-object` &middot; `spread` &middot; `hard-link`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : file_id * file_id -> order
```

`compare (a, b)` orders two file identities, so that they can be kept in a map.

<details><summary>Tests (4)</summary>

For `OS.FileSys`, in [tests/basis/os.filesys.sml](../../../../tests/basis/os.filesys.sml): `EQUAL-iff-equal` &middot; `antisymmetric` &middot; `transitive` &middot; `same-object`

</details>

## See also

[`OS_PATH`](../sig/OS_PATH.md), [`OS`](../sig/OS.md), [`OS_IO`](../sig/OS_IO.md), [`POSIX_FILE_SYS`](../sig/POSIX_FILE_SYS.md), [`TIME`](../sig/TIME.md)

---

<sub>Generated by runedoc from lib/basis/sig\_os\_file\_sys.sml; do not edit.</sub>
