# signature OS_PATH

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **OS_PATH**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 27 of 27 entries documented |
| Tests | 104 checks of 27 entries |
| Source | [lib/basis/sig\_os\_path.sml](../../../../lib/basis/sig_os_path.sml) |

## Synopsis

```sml
signature OS_PATH
structure OS.Path : OS_PATH
```

| Implementation |  | Source |
| --- | --- | --- |
| `OS.Path` |  | [lib/basis/os.sml](../../../../lib/basis/os.sml) |

Paths as text: taking them apart, putting them together, and nothing else.

Every function here works on the string alone. None of them touches the
file system, so a path may name nothing and still be split, joined and
canonicalised.

A path is a volume, a flag saying whether it is absolute, and a list of
arcs -- the pieces between the separators. [`fromString`](#val-fromstring) and [`toString`](#val-tostring)
convert between the string and that triple, and the rest is built on them.
An arc may be empty: `"a/"` has the arcs `["a", ""]`, and that empty arc
is kept, because dropping it would change what the path means to some
systems.

> **Implementation** `OS.Path/unix-syntax`. Rune's paths are Unix paths: the
> separator is `/`, the only volume is the empty string, and
> [`fromUnixPath`](#val-fromunixpath) and [`toUnixPath`](#val-tounixpath) are the identity.

## Interface

<pre>
signature OS_PATH =
sig
  exception <a href="#exn-path">Path</a>

  exception <a href="#exn-invalidarc">InvalidArc</a>

  val <a href="#val-parentarc">parentArc</a> : string

  val <a href="#val-currentarc">currentArc</a> : string

  val <a href="#val-fromstring">fromString</a> : string -&gt; {<a href="#fld-fromstring.isabs">isAbs</a> : bool, <a href="#fld-fromstring.vol">vol</a> : string, <a href="#fld-fromstring.arcs">arcs</a> : string list}

  val <a href="#val-tostring">toString</a> : {<a href="#fld-tostring.isabs">isAbs</a> : bool, <a href="#fld-tostring.vol">vol</a> : string, <a href="#fld-tostring.arcs">arcs</a> : string list} -&gt; string

  val <a href="#val-validvolume">validVolume</a> : {<a href="#fld-validvolume.isabs">isAbs</a> : bool, <a href="#fld-validvolume.vol">vol</a> : string} -&gt; bool

  val <a href="#val-getvolume">getVolume</a> : string -&gt; string

  val <a href="#val-getparent">getParent</a> : string -&gt; string

  val <a href="#val-splitdirfile">splitDirFile</a> : string -&gt; {<a href="#fld-splitdirfile.dir">dir</a> : string, <a href="#fld-splitdirfile.file">file</a> : string}

  val <a href="#val-joindirfile">joinDirFile</a> : {<a href="#fld-joindirfile.dir">dir</a> : string, <a href="#fld-joindirfile.file">file</a> : string} -&gt; string

  val <a href="#val-dir">dir</a> : string -&gt; string

  val <a href="#val-file">file</a> : string -&gt; string

  val <a href="#val-splitbaseext">splitBaseExt</a> : string -&gt; {<a href="#fld-splitbaseext.base">base</a> : string, <a href="#fld-splitbaseext.ext">ext</a> : string option}

  val <a href="#val-joinbaseext">joinBaseExt</a> : {<a href="#fld-joinbaseext.base">base</a> : string, <a href="#fld-joinbaseext.ext">ext</a> : string option} -&gt; string

  val <a href="#val-base">base</a> : string -&gt; string

  val <a href="#val-ext">ext</a> : string -&gt; string option

  val <a href="#val-mkcanonical">mkCanonical</a> : string -&gt; string

  val <a href="#val-iscanonical">isCanonical</a> : string -&gt; bool

  val <a href="#val-mkabsolute">mkAbsolute</a> : {<a href="#fld-mkabsolute.path">path</a> : string, <a href="#fld-mkabsolute.relativeto">relativeTo</a> : string} -&gt; string

  val <a href="#val-mkrelative">mkRelative</a> : {<a href="#fld-mkrelative.path">path</a> : string, <a href="#fld-mkrelative.relativeto">relativeTo</a> : string} -&gt; string

  val <a href="#val-isabsolute">isAbsolute</a> : string -&gt; bool

  val <a href="#val-isrelative">isRelative</a> : string -&gt; bool

  val <a href="#val-isroot">isRoot</a> : string -&gt; bool

  val <a href="#val-concat">concat</a> : string * string -&gt; string

  val <a href="#val-fromunixpath">fromUnixPath</a> : string -&gt; string

  val <a href="#val-tounixpath">toUnixPath</a> : string -&gt; string
end
</pre>

### <a name="exn-path"></a>`Path`

```sml
exception Path
```

Raised when a path cannot be built: an argument is not of the shape the operation needs.

[`mkAbsolute`](#val-mkabsolute) and [`mkRelative`](#val-mkrelative) raise it when `relativeTo` is not
absolute, and [`mkRelative`](#val-mkrelative) when `path` is absolute and `relativeTo` is
not.

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `raise-handle` (raises) &middot; `is-not-InvalidArc`

</details>

### <a name="exn-invalidarc"></a>`InvalidArc`

```sml
exception InvalidArc
```

Raised when an arc holds something no arc may hold.

> **Implementation** `OS.Path.InvalidArc/what-is-invalid`. On Unix an arc is
> invalid exactly when it contains a `/`.

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `raise-handle` (raises) &middot; `is-not-Path`

</details>

### <a name="val-parentarc"></a>`parentArc`

```sml
val parentArc : string
```

The arc that names the directory above: `".."`.

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `unix`

</details>

### <a name="val-currentarc"></a>`currentArc`

```sml
val currentArc : string
```

The arc that names the directory itself: `"."`.

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `unix`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> {isAbs : bool, vol : string, arcs : string list}
```

`fromString p` is `p` taken apart into whether it is absolute, its volume, and its arcs.

> **Reading** `OS.Path.fromString/empty-arcs`. The arcs are the pieces
> between the separators, empty ones included: `"/"` gives `[""]`, `"//"`
> gives `["", ""]`, `"a/"` gives `["a", ""]`, and `""` gives no arcs at
> all.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-fromstring.isabs"></a>`isAbs` | `bool` |  |
| <a name="fld-fromstring.vol"></a>`vol` | `string` |  |
| <a name="fld-fromstring.arcs"></a>`arcs` | `string list` |  |

<details><summary>Tests (5)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `two-arcs` &middot; `backslash-is-not-a-separator` &middot; `special-arcs` &middot; `inverts-toString-random`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : {isAbs : bool, vol : string, arcs : string list} -> string
```

`toString {isAbs, vol, arcs}` is the path those three make.

**Raises** [`Path`](#exn-path) if `vol` is no valid volume for `isAbs`; [`InvalidArc`](#exn-invalidarc) if
an arc is not a valid arc.

> **Reading** `OS.Path.toString/inverts-fromString`. "`fromString o toString` is the identity" holds except for the absolute path with no
> arcs, which no string produces; where it cannot hold, the exception
> [`Path`](#exn-path) counts as holding too.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-tostring.isabs"></a>`isAbs` | `bool` |  |
| <a name="fld-tostring.vol"></a>`vol` | `string` |  |
| <a name="fld-tostring.arcs"></a>`arcs` | `string list` |  |

<details><summary>Tests (14)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `empty` &middot; `absolute` &middot; `special-arcs` &middot; `non-initial-empty-arcs` &middot; `invalid-volume-Path` (raises) &middot; `invalid-volume-relative-Path` (raises) &middot; `relative-initial-empty-arc-Path` (raises) &middot; `relative-only-empty-arc-Path` (raises) &middot; `separator-in-arc-InvalidArc` (raises) &middot; `separator-arc-InvalidArc` (raises) &middot; `relative-is-relative` &middot; `inverts-fromString-random` &middot; `relative-is-relative-random`

</details>

### <a name="val-validvolume"></a>`validVolume`

```sml
val validVolume : {isAbs : bool, vol : string} -> bool
```

`validVolume {isAbs, vol}` is `true` when `vol` is a volume a path of that kind may have.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-validvolume.isabs"></a>`isAbs` | `bool` |  |
| <a name="fld-validvolume.vol"></a>`vol` | `string` |  |

<details><summary>Tests (5)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `empty-absolute` &middot; `empty-relative` &middot; `drive-absolute` &middot; `drive-relative` &middot; `separator`

</details>

### <a name="val-getvolume"></a>`getVolume`

```sml
val getVolume : string -> string
```

`getVolume p` is the volume of `p`, the empty string on Unix.

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

### <a name="val-getparent"></a>`getParent`

```sml
val getParent : string -> string
```

`getParent p` is the path of the directory that holds what `p` names.

It is `p` itself exactly when `p` is a root.

> **Reading** `OS.Path.getParent/trailing-separator`. For a path that ends in
> a separator the parent arc is appended after it: `"a/"` gives `"a/.."`
> and `"a///"` gives `"a///.."`.

<details><summary>Tests (4)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `*` &middot; `only-a-root-is-its-own-parent` &middot; `keeps-canonical-random`

</details>

### <a name="val-splitdirfile"></a>`splitDirFile`

```sml
val splitDirFile : string -> {dir : string, file : string}
```

`splitDirFile p` is `p` split into everything but its last arc, and that last arc.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-splitdirfile.dir"></a>`dir` | `string` |  |
| <a name="fld-splitdirfile.file"></a>`file` | `string` |  |

<details><summary>Tests (4)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `last-arc` &middot; `parent-arc` &middot; `file-is-last-arc-random`

</details>

### <a name="val-joindirfile"></a>`joinDirFile`

```sml
val joinDirFile : {dir : string, file : string} -> string
```

`joinDirFile {dir, file}` is the path of `file` inside `dir`.

**Raises** [`InvalidArc`](#exn-invalidarc) if `file` is not a valid arc.

> **Reading** `OS.Path.joinDirFile/undoes-splitDirFile`. It undoes
> [`splitDirFile`](#val-splitdirfile) on every path of the specification's table except the
> empty one.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-joindirfile.dir"></a>`dir` | `string` |  |
| <a name="fld-joindirfile.file"></a>`file` | `string` |  |

<details><summary>Tests (6)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `relative` &middot; `absolute` &middot; `parent-arc` &middot; `path-as-file-InvalidArc` (raises) &middot; `root-as-file-InvalidArc` (raises)

</details>

### <a name="val-dir"></a>`dir`

```sml
val dir : string -> string
```

`dir p` is the [`dir`](#val-dir) part of `splitDirFile p`.

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `is-splitDirFile-random`

</details>

### <a name="val-file"></a>`file`

```sml
val file : string -> string
```

`file p` is the [`file`](#val-file) part of `splitDirFile p`: the last arc of `p`.

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `is-splitDirFile-random`

</details>

### <a name="val-splitbaseext"></a>`splitBaseExt`

```sml
val splitBaseExt : string -> {base : string, ext : string option}
```

`splitBaseExt p` is `p` split into what comes before the extension and the extension.

The extension is the text after the right-most `.` of the last arc, when
that `.` is not the first character of the arc and something follows it;
otherwise there is none.

> **Reading** `OS.Path.splitBaseExt/base-keeps-empty-arcs`. The base is
> everything to the left of the extension, empty arcs and all: `"a//c.x"`
> has the base `"a//c"`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-splitbaseext.base"></a>`base` | `string` |  |
| <a name="fld-splitbaseext.ext"></a>`ext` | `string option` |  |

<details><summary>Tests (10)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `only-the-last-arc` &middot; `dot-in-directory` &middot; `initial-dot-of-last-arc` &middot; `second-dot-of-last-arc` &middot; `parent-arc` &middot; `trailing-separator` &middot; `empty-arc` &middot; `root-empty-arc` &middot; `never-SOME-empty-random`

</details>

### <a name="val-joinbaseext"></a>`joinBaseExt`

```sml
val joinBaseExt : {base : string, ext : string option} -> string
```

`joinBaseExt {base, ext}` is `base` with `ext` appended after a `.`, or `base` alone when `ext` is `NONE`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-joinbaseext.base"></a>`base` | `string` |  |
| <a name="fld-joinbaseext.ext"></a>`ext` | `string option` |  |

<details><summary>Tests (7)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `SOME` &middot; `NONE` &middot; `SOME-empty-is-NONE` &middot; `path-base` &middot; `not-a-right-inverse` &middot; `inverts-splitBaseExt-random`

</details>

### <a name="val-base"></a>`base`

```sml
val base : string -> string
```

`base p` is the [`base`](#val-base) part of `splitBaseExt p`.

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `is-splitBaseExt-random`

</details>

### <a name="val-ext"></a>`ext`

```sml
val ext : string -> string option
```

`ext p` is the [`ext`](#val-ext) part of `splitBaseExt p`.

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `is-splitBaseExt-random`

</details>

### <a name="val-mkcanonical"></a>`mkCanonical`

```sml
val mkCanonical : string -> string
```

`mkCanonical p` is `p` with the current arcs dropped, the parent arcs cancelled where they can be, and the separators made single.

> **Reading** `OS.Path.mkCanonical/root-current-arc`. `"/."` becomes `"/"`,
> because "redundant current arcs are removed", although the
> specification's list of canonical paths has `"/."` among them; every
> host agrees on `"/"`.

<details><summary>Tests (5)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*` &middot; `equality-of-paths` &middot; `is-canonical-random` &middot; `never-empty-random` &middot; `keeps-isAbsolute-random`

</details>

### <a name="val-iscanonical"></a>`isCanonical`

```sml
val isCanonical : string -> bool
```

`isCanonical p` is `true` when `p` is what [`mkCanonical`](#val-mkcanonical) would give.

<details><summary>Tests (4)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `example-*` &middot; `example-root-current-arc` &middot; `not-*` &middot; `is-mkCanonical-equality-random`

</details>

### <a name="val-mkabsolute"></a>`mkAbsolute`

```sml
val mkAbsolute : {path : string, relativeTo : string} -> string
```

`mkAbsolute {path, relativeTo}` is `path` read as lying under `relativeTo`, canonicalised.

`path` is given back canonicalised when it is already absolute.

**Raises** [`Path`](#exn-path) if `relativeTo` is not absolute -- also when `path`
already is.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mkabsolute.path"></a>`path` | `string` |  |
| <a name="fld-mkabsolute.relativeto"></a>`relativeTo` | `string` |  |

<details><summary>Tests (5)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*` &middot; `relativeTo-relative-Path` (raises) &middot; `relativeTo-empty-Path` (raises) &middot; `keeps-canonical-random` &middot; `inverts-mkRelative-random`

</details>

### <a name="val-mkrelative"></a>`mkRelative`

```sml
val mkRelative : {path : string, relativeTo : string} -> string
```

`mkRelative {path, relativeTo}` is `path` written as a path from `relativeTo`.

**Raises** [`Path`](#exn-path) if `relativeTo` is not absolute -- also when `path` is
already relative.

> **Reading** `OS.Path.mkRelative/what-is-kept`. `relativeTo` is
> canonicalised first, while the arcs of `path` are kept as written, a
> trailing empty arc included: `"/a/b/"` relative to `"/a/c"` is
> `"../b/"`. A root alone has no arcs to keep.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mkrelative.path"></a>`path` | `string` |  |
| <a name="fld-mkrelative.relativeto"></a>`relativeTo` | `string` |  |

<details><summary>Tests (10)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `relative-unchanged` &middot; `equal` &middot; `equal-to-canonical` &middot; `below` &middot; `above` &middot; `relativeTo-relative-Path` (raises) &middot; `relativeTo-empty-Path` (raises) &middot; `keeps-canonical-random` &middot; `is-relative-random`

</details>

### <a name="val-isabsolute"></a>`isAbsolute`

```sml
val isAbsolute : string -> bool
```

`isAbsolute p` is `true` when `p` starts from a root.

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*` &middot; `not-isRelative-random`

</details>

### <a name="val-isrelative"></a>`isRelative`

```sml
val isRelative : string -> bool
```

`isRelative p` is `true` when `p` does not start from a root.

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

### <a name="val-isroot"></a>`isRoot`

```sml
val isRoot : string -> bool
```

`isRoot p` is `true` when `p` is a canonical absolute path with no arcs below the root.

> **Reading** `OS.Path.isRoot/double-separator`. `"/"` is a root and `"//"`
> is not: the second has an empty arc under the root.

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : string * string -> string
```

`concat (p, q)` is `q` read as lying under `p`.

**Raises** [`Path`](#exn-path) if `q` is absolute, or if `q` is relative and `p` has a
volume that `q` does not.

> **Reading** `OS.Path.concat/keeps-the-parent-arc`. The arcs of `q` are
> appended to those of `p` without cancelling: a `p` that ends in the
> parent arc keeps it. A trailing empty arc of `p` is absorbed by the
> join.

<details><summary>Tests (4)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*` &middot; `absolute-second-Path` (raises) &middot; `root-second-Path` (raises) &middot; `arcs-random`

</details>

### <a name="val-fromunixpath"></a>`fromUnixPath`

```sml
val fromUnixPath : string -> string
```

`fromUnixPath p` is the path that `p` names on this system, `p` itself on Unix.

**Raises** [`InvalidArc`](#exn-invalidarc) if an arc of `p` cannot be one here.

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

### <a name="val-tounixpath"></a>`toUnixPath`

```sml
val toUnixPath : string -> string
```

`toUnixPath p` is `p` written in Unix syntax, `p` itself on Unix.

**Raises** [`Path`](#exn-path) if `p` has a volume that Unix syntax cannot write.

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

## See also

[`OS_FILE_SYS`](../sig/OS_FILE_SYS.md), [`OS`](../sig/OS.md), [`SUBSTRING`](../sig/SUBSTRING.md)

---

<sub>Generated by runedoc from lib/basis/sig\_os\_path.sml; do not edit.</sub>
