# structure OS.Path

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **OS.Path**

|  |  |
| --- | --- |
| Signature | [`OS_PATH`](../sig/OS_PATH.md) |
| Status | required |
| Members | 27 |
| Tests | 72 checks |
| Source | [lib/basis/ospath.sml](../../../../lib/basis/ospath.sml) |

## Synopsis

```sml
structure OS.Path : OS_PATH
```

OS.Path: paths as text. Nothing here looks at a file system.

The separator is "/" and the only volume is "", as on Unix, which is what
the VM runs on.

## Members

What each means is on [`OS_PATH`](../sig/OS_PATH.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| exception | [`InvalidArc`](../sig/OS_PATH.md#exn-invalidarc) |  |
| exception | [`Path`](../sig/OS_PATH.md#exn-path) |  |
| val | [`base`](../sig/OS_PATH.md#val-base) | `string -> string` |
| val | [`concat`](../sig/OS_PATH.md#val-concat) | `string * string -> string` |
| val | [`currentArc`](../sig/OS_PATH.md#val-currentarc) | `string` |
| val | [`dir`](../sig/OS_PATH.md#val-dir) | `string -> string` |
| val | [`ext`](../sig/OS_PATH.md#val-ext) | `string -> string option` |
| val | [`file`](../sig/OS_PATH.md#val-file) | `string -> string` |
| val | [`fromString`](../sig/OS_PATH.md#val-fromstring) | `string -> {arcs : string list, isAbs : bool, vol : string}` |
| val | [`fromUnixPath`](../sig/OS_PATH.md#val-fromunixpath) | `string -> string` |
| val | [`getParent`](../sig/OS_PATH.md#val-getparent) | `string -> string` |
| val | [`getVolume`](../sig/OS_PATH.md#val-getvolume) | `string -> string` |
| val | [`isAbsolute`](../sig/OS_PATH.md#val-isabsolute) | `string -> bool` |
| val | [`isCanonical`](../sig/OS_PATH.md#val-iscanonical) | `string -> bool` |
| val | [`isRelative`](../sig/OS_PATH.md#val-isrelative) | `string -> bool` |
| val | [`isRoot`](../sig/OS_PATH.md#val-isroot) | `string -> bool` |
| val | [`joinBaseExt`](../sig/OS_PATH.md#val-joinbaseext) | `{base : string, ext : string option} -> string` |
| val | [`joinDirFile`](../sig/OS_PATH.md#val-joindirfile) | `{dir : string, file : string} -> string` |
| val | [`mkAbsolute`](../sig/OS_PATH.md#val-mkabsolute) | `{path : string, relativeTo : string} -> string` |
| val | [`mkCanonical`](../sig/OS_PATH.md#val-mkcanonical) | `string -> string` |
| val | [`mkRelative`](../sig/OS_PATH.md#val-mkrelative) | `{path : string, relativeTo : string} -> string` |
| val | [`parentArc`](../sig/OS_PATH.md#val-parentarc) | `string` |
| val | [`splitBaseExt`](../sig/OS_PATH.md#val-splitbaseext) | `string -> {base : string, ext : string option}` |
| val | [`splitDirFile`](../sig/OS_PATH.md#val-splitdirfile) | `string -> {dir : string, file : string}` |
| val | [`toString`](../sig/OS_PATH.md#val-tostring) | `{arcs : string list, isAbs : bool, vol : string} -> string` |
| val | [`toUnixPath`](../sig/OS_PATH.md#val-tounixpath) | `string -> string` |
| val | [`validVolume`](../sig/OS_PATH.md#val-validvolume) | `{isAbs : bool, vol : string} -> bool` |

## Notes

### 

> **Implementation** `OS.Path/unix-syntax`. Rune's paths are Unix paths: the
> separator is `/`, the only volume is the empty string, and
> [`fromUnixPath`](../sig/OS_PATH.md#val-fromunixpath) and [`toUnixPath`](../sig/OS_PATH.md#val-tounixpath) are the identity. That holds on Windows
> as well, where the system layer of the VM hands the library a path of a
> drive as `/C:/Users/...`, which is absolute by these rules since no name
> of Windows has a colon in it, and gives Windows back `C:/...`. The syntax
> the specification describes for Windows, with the volume `C:` and `\`
> between the arcs, is not implemented.

### InvalidArc

> **Implementation** `OS.Path.InvalidArc/what-is-invalid`. On Unix an arc is
> invalid exactly when it contains a `/`.

### concat

> **Reading** `OS.Path.concat/keeps-the-parent-arc`. The arcs of `q` are
> appended to those of `p` without cancelling: a `p` that ends in the
> parent arc keeps it. A trailing empty arc of `p` is absorbed by the
> join.

### fromString

> **Reading** `OS.Path.fromString/empty-arcs`. The arcs are the pieces
> between the separators, empty ones included: `"/"` gives `[""]`, `"//"`
> gives `["", ""]`, `"a/"` gives `["a", ""]`, and `""` gives no arcs at
> all.

### getParent

> **Reading** `OS.Path.getParent/trailing-separator`. For a path that ends in
> a separator the parent arc is appended after it: `"a/"` gives `"a/.."`
> and `"a///"` gives `"a///.."`.

### isRoot

> **Reading** `OS.Path.isRoot/double-separator`. `"/"` is a root and `"//"`
> is not: the second has an empty arc under the root.

### joinDirFile

> **Reading** `OS.Path.joinDirFile/undoes-splitDirFile`. It undoes
> [`splitDirFile`](../sig/OS_PATH.md#val-splitdirfile) on every path of the specification's table except the
> empty one.

### mkCanonical

> **Reading** `OS.Path.mkCanonical/root-current-arc`. `"/."` becomes `"/"`,
> because "redundant current arcs are removed", although the
> specification's list of canonical paths has `"/."` among them; every
> host agrees on `"/"`.

### mkRelative

> **Reading** `OS.Path.mkRelative/what-is-kept`. `relativeTo` is
> canonicalised first, while the arcs of `path` are kept as written, a
> trailing empty arc included: `"/a/b/"` relative to `"/a/c"` is
> `"../b/"`. A root alone has no arcs to keep.

### splitBaseExt

> **Reading** `OS.Path.splitBaseExt/base-keeps-empty-arcs`. The base is
> everything to the left of the extension, empty arcs and all: `"a//c.x"`
> has the base `"a//c"`.

### toString

> **Reading** `OS.Path.toString/inverts-fromString`. "`fromString o toString` is the identity" holds except for the absolute path with no
> arcs, which no string produces; where it cannot hold, the exception
> [`Path`](../sig/OS_PATH.md#exn-path) counts as holding too.

<details><summary>Other implementations (11)</summary>

- **Poly/ML** &mdash; toString {isAbs = false, vol = "", arcs = \[""\]} returns "" instead of raising Path, and fromString "" has no arcs
- **SML/NJ** &mdash; fromUnixPath "" is "/" instead of "" (on a Unix system the path syntax of the host is that of Unix)
- **Poly/ML** &mdash; fromUnixPath of an absolute path doubles the root: "/a/../b/" gives "//a/../b/" (on a Unix system the path syntax of the host is that of Unix)
- **SML/NJ** &mdash; the random canonical paths come from mkCanonical, which raises Fail on "./" and "a/../"
- **Poly/ML** &mdash; getParent "a/." is "a", not "a/.." ("If the last arc is the current arc, then it is replaced with the parent arc")
- **SML/NJ** &mdash; mkCanonical raises Fail on the random paths that reduce to no arc but end with an empty one ("./", "a/../")
- **MLton, SML/NJ** &mdash; joinBaseExt o splitBaseExt is not the identity on a path with an empty arc, which splitBaseExt drops from the base ("a//c.d" gives base "a/c")
- **SML/NJ** &mdash; mkCanonical raises Fail on a relative path that reduces to no arc but ends with an empty one ("./", ".//", "a/../") instead of returning "."
- **MLton, SML/NJ** &mdash; the base that splitBaseExt returns leaves out empty arcs: splitBaseExt "a//c.d" is {base = "a/c", ext = SOME "d"}, not "a//c" ("everything to the left of the extension except the final "."")
- **Poly/ML** &mdash; toString {isAbs = false, vol = "", arcs = \[""\]} returns "" instead of raising Path ("if isAbs is false and arcs has an initial empty arc")
- **Poly/ML** &mdash; toUnixPath "/" is "" instead of "/"

</details>

---

<sub>Generated by runedoc from lib/basis/ospath.sml; do not edit.</sub>
