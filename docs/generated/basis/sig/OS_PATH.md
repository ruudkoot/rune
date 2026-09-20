# signature OS_PATH

[The Standard ML Basis Library](../README.md) &rsaquo; **OS_PATH**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 27 entries documented |
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

signature OS\_PATH, transcribed from
<https://smlfamily.github.io/Basis/os-path.html>

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

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `raise-handle` (raises) &middot; `is-not-InvalidArc`

</details>

### <a name="exn-invalidarc"></a>`InvalidArc`

```sml
exception InvalidArc
```

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `raise-handle` (raises) &middot; `is-not-Path`

</details>

### <a name="val-parentarc"></a>`parentArc`

```sml
val parentArc : string
```

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `unix`

</details>

### <a name="val-currentarc"></a>`currentArc`

```sml
val currentArc : string
```

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `unix`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> {isAbs : bool, vol : string, arcs : string list}
```

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

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

### <a name="val-getparent"></a>`getParent`

```sml
val getParent : string -> string
```

<details><summary>Tests (4)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `*` &middot; `only-a-root-is-its-own-parent` &middot; `keeps-canonical-random`

</details>

### <a name="val-splitdirfile"></a>`splitDirFile`

```sml
val splitDirFile : string -> {dir : string, file : string}
```

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

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `is-splitDirFile-random`

</details>

### <a name="val-file"></a>`file`

```sml
val file : string -> string
```

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `is-splitDirFile-random`

</details>

### <a name="val-splitbaseext"></a>`splitBaseExt`

```sml
val splitBaseExt : string -> {base : string, ext : string option}
```

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

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `is-splitBaseExt-random`

</details>

### <a name="val-ext"></a>`ext`

```sml
val ext : string -> string option
```

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `row-*` &middot; `is-splitBaseExt-random`

</details>

### <a name="val-mkcanonical"></a>`mkCanonical`

```sml
val mkCanonical : string -> string
```

<details><summary>Tests (5)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*` &middot; `equality-of-paths` &middot; `is-canonical-random` &middot; `never-empty-random` &middot; `keeps-isAbsolute-random`

</details>

### <a name="val-iscanonical"></a>`isCanonical`

```sml
val isCanonical : string -> bool
```

<details><summary>Tests (4)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `example-*` &middot; `example-root-current-arc` &middot; `not-*` &middot; `is-mkCanonical-equality-random`

</details>

### <a name="val-mkabsolute"></a>`mkAbsolute`

```sml
val mkAbsolute : {path : string, relativeTo : string} -> string
```

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

<details><summary>Tests (2)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*` &middot; `not-isRelative-random`

</details>

### <a name="val-isrelative"></a>`isRelative`

```sml
val isRelative : string -> bool
```

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

### <a name="val-isroot"></a>`isRoot`

```sml
val isRoot : string -> bool
```

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

### <a name="val-concat"></a>`concat`

```sml
val concat : string * string -> string
```

<details><summary>Tests (4)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*` &middot; `absolute-second-Path` (raises) &middot; `root-second-Path` (raises) &middot; `arcs-random`

</details>

### <a name="val-fromunixpath"></a>`fromUnixPath`

```sml
val fromUnixPath : string -> string
```

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

### <a name="val-tounixpath"></a>`toUnixPath`

```sml
val toUnixPath : string -> string
```

<details><summary>Tests (1)</summary>

For `OS.Path`, in [tests/basis/os.path.sml](../../../../tests/basis/os.path.sml): `*`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_os\_path.sml; do not edit.</sub>
