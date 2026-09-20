(* Paths as text: taking them apart, putting them together, and nothing else.

   Every function here works on the string alone. None of them touches the
   file system, so a path may name nothing and still be split, joined and
   canonicalised.

   A path is a volume, a flag saying whether it is absolute, and a list of
   arcs -- the pieces between the separators. `fromString` and `toString`
   convert between the string and that triple, and the rest is built on them.
   An arc may be empty: `"a/"` has the arcs `["a", ""]`, and that empty arc
   is kept, because dropping it would change what the path means to some
   systems.

   Area: The operating system

   See also: `OS_FILE_SYS`, `OS`, `SUBSTRING`

   Implementation: `OS.Path/unix-syntax`. Rune's paths are Unix paths: the
   separator is `/`, the only volume is the empty string, and
   `fromUnixPath` and `toUnixPath` are the identity.

   Pinned by: `OS.Path.parentArc/unix`, `OS.Path.currentArc/unix`,
   `OS.Path.validVolume/*` *)
signature OS_PATH =
sig
  (* Raised when a path cannot be built: an argument is not of the shape the operation needs.

     `mkAbsolute` and `mkRelative` raise it when `relativeTo` is not
     absolute, and `mkRelative` when `path` is absolute and `relativeTo` is
     not. *)
  exception Path

  (* Raised when an arc holds something no arc may hold.

     Implementation: `OS.Path.InvalidArc/what-is-invalid`. On Unix an arc is
     invalid exactly when it contains a `/`. *)
  exception InvalidArc

  (* The arc that names the directory above: `".."`. *)
  val parentArc : string

  (* The arc that names the directory itself: `"."`. *)
  val currentArc : string

  (* `fromString p` is `p` taken apart into whether it is absolute, its volume, and its arcs.

     Reading: `OS.Path.fromString/empty-arcs`. The arcs are the pieces
     between the separators, empty ones included: `"/"` gives `[""]`, `"//"`
     gives `["", ""]`, `"a/"` gives `["a", ""]`, and `""` gives no arcs at
     all. *)
  val fromString : string -> {isAbs : bool, vol : string, arcs : string list}

  (* `toString {isAbs, vol, arcs}` is the path those three make.

     Raises: `Path` if `vol` is no valid volume for `isAbs`; `InvalidArc` if
     an arc is not a valid arc.

     Reading: `OS.Path.toString/inverts-fromString`. "`fromString o
     toString` is the identity" holds except for the absolute path with no
     arcs, which no string produces; where it cannot hold, the exception
     `Path` counts as holding too.

     Pinned by: `OS.Path.fromString/inverts-toString-random` *)
  val toString : {isAbs : bool, vol : string, arcs : string list} -> string

  (* `validVolume {isAbs, vol}` is `true` when `vol` is a volume a path of that kind may have. *)
  val validVolume : {isAbs : bool, vol : string} -> bool

  (* `getVolume p` is the volume of `p`, the empty string on Unix. *)
  val getVolume : string -> string

  (* `getParent p` is the path of the directory that holds what `p` names.

     It is `p` itself exactly when `p` is a root.

     Reading: `OS.Path.getParent/trailing-separator`. For a path that ends in
     a separator the parent arc is appended after it: `"a/"` gives `"a/.."`
     and `"a///"` gives `"a///.."`. *)
  val getParent : string -> string

  (* `splitDirFile p` is `p` split into everything but its last arc, and that last arc. *)
  val splitDirFile : string -> {dir : string, file : string}

  (* `joinDirFile {dir, file}` is the path of `file` inside `dir`.

     Raises: `InvalidArc` if `file` is not a valid arc.

     Reading: `OS.Path.joinDirFile/undoes-splitDirFile`. It undoes
     `splitDirFile` on every path of the specification's table except the
     empty one.

     Pinned by: `OS.Path.joinDirFile/row-*` *)
  val joinDirFile : {dir : string, file : string} -> string

  (* `dir p` is the `dir` part of `splitDirFile p`. *)
  val dir : string -> string

  (* `file p` is the `file` part of `splitDirFile p`: the last arc of `p`. *)
  val file : string -> string

  (* `splitBaseExt p` is `p` split into what comes before the extension and the extension.

     The extension is the text after the right-most `.` of the last arc, when
     that `.` is not the first character of the arc and something follows it;
     otherwise there is none.

     Reading: `OS.Path.splitBaseExt/base-keeps-empty-arcs`. The base is
     everything to the left of the extension, empty arcs and all: `"a//c.x"`
     has the base `"a//c"`. *)
  val splitBaseExt : string -> {base : string, ext : string option}

  (* `joinBaseExt {base, ext}` is `base` with `ext` appended after a `.`, or `base` alone when `ext` is `NONE`. *)
  val joinBaseExt : {base : string, ext : string option} -> string

  (* `base p` is the `base` part of `splitBaseExt p`. *)
  val base : string -> string

  (* `ext p` is the `ext` part of `splitBaseExt p`. *)
  val ext : string -> string option

  (* `mkCanonical p` is `p` with the current arcs dropped, the parent arcs cancelled where they can be, and the separators made single.

     Reading: `OS.Path.mkCanonical/root-current-arc`. `"/."` becomes `"/"`,
     because "redundant current arcs are removed", although the
     specification's list of canonical paths has `"/."` among them; every
     host agrees on `"/"`.

     Pinned by: `OS.Path.isCanonical/example-root-current-arc` *)
  val mkCanonical : string -> string

  (* `isCanonical p` is `true` when `p` is what `mkCanonical` would give. *)
  val isCanonical : string -> bool

  (* `mkAbsolute {path, relativeTo}` is `path` read as lying under `relativeTo`, canonicalised.

     `path` is given back canonicalised when it is already absolute.

     Raises: `Path` if `relativeTo` is not absolute -- also when `path`
     already is. *)
  val mkAbsolute : {path : string, relativeTo : string} -> string

  (* `mkRelative {path, relativeTo}` is `path` written as a path from `relativeTo`.

     Raises: `Path` if `relativeTo` is not absolute -- also when `path` is
     already relative.

     Reading: `OS.Path.mkRelative/what-is-kept`. `relativeTo` is
     canonicalised first, while the arcs of `path` are kept as written, a
     trailing empty arc included: `"/a/b/"` relative to `"/a/c"` is
     `"../b/"`. A root alone has no arcs to keep.

     Pinned by: `OS.Path.mkAbsolute/inverts-mkRelative-random`,
     `OS.Path.mkRelative/is-relative-random` *)
  val mkRelative : {path : string, relativeTo : string} -> string

  (* `isAbsolute p` is `true` when `p` starts from a root. *)
  val isAbsolute : string -> bool

  (* `isRelative p` is `true` when `p` does not start from a root. *)
  val isRelative : string -> bool

  (* `isRoot p` is `true` when `p` is a canonical absolute path with no arcs below the root.

     Reading: `OS.Path.isRoot/double-separator`. `"/"` is a root and `"//"`
     is not: the second has an empty arc under the root. *)
  val isRoot : string -> bool

  (* `concat (p, q)` is `q` read as lying under `p`.

     Raises: `Path` if `q` is absolute, or if `q` is relative and `p` has a
     volume that `q` does not.

     Reading: `OS.Path.concat/keeps-the-parent-arc`. The arcs of `q` are
     appended to those of `p` without cancelling: a `p` that ends in the
     parent arc keeps it. A trailing empty arc of `p` is absorbed by the
     join. *)
  val concat : string * string -> string

  (* `fromUnixPath p` is the path that `p` names on this system, `p` itself on Unix.

     Raises: `InvalidArc` if an arc of `p` cannot be one here. *)
  val fromUnixPath : string -> string

  (* `toUnixPath p` is `p` written in Unix syntax, `p` itself on Unix.

     Raises: `Path` if `p` has a volume that Unix syntax cannot write. *)
  val toUnixPath : string -> string
end
