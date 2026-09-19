(* requires: OS *)
(* OS.Path (signature OS_PATH). Expected values follow the text of
   https://smlfamily.github.io/Basis/os-path.html: every row of its tables
   (fromString, getParent, splitDirFile, splitBaseExt, mkRelative), the
   examples of its text, and the laws it states, some of them on
   pseudo-random paths. Every system of the matrix is a Unix, so the path
   syntax is that of the Unix examples: the arc separator is #"/" and the only
   volume is "". Nothing here touches the file system.

   A path in a label is written with "_" for "/", and the empty path as
   "empty": "OS.Path.getParent/row-a___" is the row for "a///". *)
structure TestOSPath =
struct
  val eqS = T.eq T.string
  val eqB = T.eq T.bool
  fun showParts {isAbs, vol, arcs} =
    "{isAbs=" ^ Bool.toString isAbs ^ ", vol=" ^ T.string vol ^ ", arcs=" ^ T.list T.string arcs ^ "}"
  fun showDirFile {dir, file} = "{dir=" ^ T.string dir ^ ", file=" ^ T.string file ^ "}"
  fun showBaseExt {base, ext} = "{base=" ^ T.string base ^ ", ext=" ^ T.option T.string ext ^ "}"
  val isPath = fn OS.Path.Path => true | _ => false
  val isInvalidArc = fn OS.Path.InvalidArc => true | _ => false

  fun enc "" = "empty"
    | enc p = String.map (fn #"/" => #"_" | c => c) p

  (* ---- parentArc, currentArc: ".." and "." under Unix ---- *)
  val () = eqS ("OS.Path.parentArc/unix", "..", fn () => OS.Path.parentArc)
  val () = eqS ("OS.Path.currentArc/unix", ".", fn () => OS.Path.currentArc)

  (* ---- fromString: the table of the page, and toString undoing each row
     ("toString o fromString is the identity") ---- *)
  val fromStringTable =
    [("", {isAbs = false, vol = "", arcs = []}),
     ("/", {isAbs = true, vol = "", arcs = [""]}),
     ("//", {isAbs = true, vol = "", arcs = ["", ""]}),
     ("a", {isAbs = false, vol = "", arcs = ["a"]}),
     ("/a", {isAbs = true, vol = "", arcs = ["a"]}),
     ("//a", {isAbs = true, vol = "", arcs = ["", "a"]}),
     ("a/", {isAbs = false, vol = "", arcs = ["a", ""]}),
     ("a//", {isAbs = false, vol = "", arcs = ["a", "", ""]}),
     ("a/b", {isAbs = false, vol = "", arcs = ["a", "b"]})]
  val () = List.app (fn (p, parts) => T.eq showParts ("OS.Path.fromString/row-" ^ enc p, parts,
                                                      fn () => OS.Path.fromString p))
                    fromStringTable
  val () = List.app (fn (p, parts) => eqS ("OS.Path.toString/row-" ^ enc p, p, fn () => OS.Path.toString parts))
                    fromStringTable
  (* "in Unix, the path "abc/def" contains two arcs"; "on a Unix system,
     [\\d\\e] will correspond to a relative path with one arc" *)
  val () = T.eq showParts ("OS.Path.fromString/two-arcs", {isAbs = false, vol = "", arcs = ["abc", "def"]},
                           fn () => OS.Path.fromString "abc/def")
  val () = T.eq showParts ("OS.Path.fromString/backslash-is-not-a-separator",
                           {isAbs = false, vol = "", arcs = ["\\d\\e"]}, fn () => OS.Path.fromString "\\d\\e")
  val () = T.eq showParts ("OS.Path.fromString/special-arcs", {isAbs = true, vol = "", arcs = ["..", ".", "a"]},
                           fn () => OS.Path.fromString "/.././a")

  (* ---- toString ---- *)
  (* "It returns "" when applied to {isAbs=false, vol="", arcs=[]}." *)
  val () = eqS ("OS.Path.toString/empty", "", fn () => OS.Path.toString {isAbs = false, vol = "", arcs = []})
  val () = eqS ("OS.Path.toString/absolute", "/a/b", fn () => OS.Path.toString {isAbs = true, vol = "", arcs = ["a", "b"]})
  val () = eqS ("OS.Path.toString/special-arcs", "../.", fn () => OS.Path.toString {isAbs = false, vol = "", arcs = ["..", "."]})
  val () = eqS ("OS.Path.toString/non-initial-empty-arcs", "a//b/",
                fn () => OS.Path.toString {isAbs = false, vol = "", arcs = ["a", "", "b", ""]})
  (* "The exception Path is raised if validVolume{isAbs, vol} is false, or if
     isAbs is false and arcs has an initial empty arc." *)
  val () = T.raises ("OS.Path.toString/invalid-volume-Path", isPath,
                     fn () => OS.Path.toString {isAbs = true, vol = "C:", arcs = ["a"]})
  val () = T.raises ("OS.Path.toString/invalid-volume-relative-Path", isPath,
                     fn () => OS.Path.toString {isAbs = false, vol = "A:", arcs = ["a"]})
  val () = T.raises ("OS.Path.toString/relative-initial-empty-arc-Path", isPath,
                     fn () => OS.Path.toString {isAbs = false, vol = "", arcs = ["", "a"]})
  val () = T.raises ("OS.Path.toString/relative-only-empty-arc-Path", isPath,
                     fn () => OS.Path.toString {isAbs = false, vol = "", arcs = [""]})
  (* "The exception InvalidArc is raised if any component in arcs is not a
     valid representation of an arc": "a non-empty string a corresponds to
     valid representation of an arc only if fromString a returns
     {isAbs=false, vol="", arcs=[a]}", which "b/c" and "/" do not. *)
  val () = T.raises ("OS.Path.toString/separator-in-arc-InvalidArc", isInvalidArc,
                     fn () => OS.Path.toString {isAbs = false, vol = "", arcs = ["a", "b/c"]})
  val () = T.raises ("OS.Path.toString/separator-arc-InvalidArc", isInvalidArc,
                     fn () => OS.Path.toString {isAbs = true, vol = "", arcs = ["/"]})
  (* "isRelative(toString {isAbs=false, vol, arcs}) evaluates to true when defined" *)
  val () = eqB ("OS.Path.toString/relative-is-relative", true,
                fn () => OS.Path.isRelative (OS.Path.toString {isAbs = false, vol = "", arcs = ["..", "a"]}))

  (* ---- validVolume, getVolume: "Under Unix, the only valid volume name is """ ---- *)
  val () = eqB ("OS.Path.validVolume/empty-absolute", true, fn () => OS.Path.validVolume {isAbs = true, vol = ""})
  val () = eqB ("OS.Path.validVolume/empty-relative", true, fn () => OS.Path.validVolume {isAbs = false, vol = ""})
  val () = eqB ("OS.Path.validVolume/drive-absolute", false, fn () => OS.Path.validVolume {isAbs = true, vol = "C:"})
  val () = eqB ("OS.Path.validVolume/drive-relative", false, fn () => OS.Path.validVolume {isAbs = false, vol = "A:"})
  val () = eqB ("OS.Path.validVolume/separator", false, fn () => OS.Path.validVolume {isAbs = true, vol = "/"})
  val () = List.app (fn p => eqS ("OS.Path.getVolume/" ^ enc p, "", fn () => OS.Path.getVolume p))
                    ["", "/", "/a/b", "a/b", "C:a", ".."]

  (* ---- getParent: the table, and the rules of the text ---- *)
  val () = List.app (fn (p, e) => eqS ("OS.Path.getParent/row-" ^ enc p, e, fn () => OS.Path.getParent p))
                    [("/", "/"), ("a", "."), ("a/", "a/.."), ("a///", "a///.."), ("a/b", "a"),
                     ("a/b/", "a/b/.."), ("..", "../.."), (".", ".."), ("", "..")]
  (* "If the last arc is empty or the parent arc, then getParent appends a
     parent arc. If the last arc is the current arc, then it is replaced with
     the parent arc." *)
  val () = List.app (fn (p, e) => eqS ("OS.Path.getParent/" ^ enc p, e, fn () => OS.Path.getParent p))
                    [("/a", "/"), ("/a/b", "/a"), ("a/b/c", "a/b"), ("a/..", "a/../.."), ("../..", "../../.."),
                     ("a/.", "a/.."), ("/a/", "/a/.."), ("//", "//..")]
  (* "getParent path = path if and only if path is a root" *)
  val () = eqB ("OS.Path.getParent/only-a-root-is-its-own-parent", true,
                fn () => List.all (fn p => (OS.Path.getParent p = p) = (p = "/"))
                                  ["/", "", ".", "..", "a", "/a", "a/", "/a/b", "a/.."])

  (* ---- splitDirFile, dir, file: the table ---- *)
  val splitDirFileTable =
    [("", {dir = "", file = ""}), (".", {dir = "", file = "."}), ("b", {dir = "", file = "b"}),
     ("b/", {dir = "b", file = ""}), ("a/b", {dir = "a", file = "b"}), ("/a", {dir = "/", file = "a"})]
  val () = List.app (fn (p, e) => T.eq showDirFile ("OS.Path.splitDirFile/row-" ^ enc p, e,
                                                    fn () => OS.Path.splitDirFile p))
                    splitDirFileTable
  (* "They are equivalent to #dir o splitDirFile and #file o splitDirFile" *)
  val () = List.app (fn (p, {dir, file}) => eqS ("OS.Path.dir/row-" ^ enc p, dir, fn () => OS.Path.dir p))
                    splitDirFileTable
  val () = List.app (fn (p, {dir, file}) => eqS ("OS.Path.file/row-" ^ enc p, file, fn () => OS.Path.file p))
                    splitDirFileTable
  (* "the file part is defined to be the last arc" *)
  val () = T.eq showDirFile ("OS.Path.splitDirFile/last-arc", {dir = "/a/b", file = "c.d"},
                             fn () => OS.Path.splitDirFile "/a/b/c.d")
  val () = T.eq showDirFile ("OS.Path.splitDirFile/parent-arc", {dir = "a", file = ".."},
                             fn () => OS.Path.splitDirFile "a/..")

  (* ---- joinDirFile: "extending the path dir with the arc file". It undoes
     splitDirFile on the rows of its table (the empty path aside). ---- *)
  val () = List.app (fn (p, df) => eqS ("OS.Path.joinDirFile/row-" ^ enc p, p, fn () => OS.Path.joinDirFile df))
                    (List.filter (fn (p, _) => p <> "") splitDirFileTable)
  val () = eqS ("OS.Path.joinDirFile/relative", "a/b/c", fn () => OS.Path.joinDirFile {dir = "a/b", file = "c"})
  val () = eqS ("OS.Path.joinDirFile/absolute", "/a/b", fn () => OS.Path.joinDirFile {dir = "/a", file = "b"})
  val () = eqS ("OS.Path.joinDirFile/parent-arc", "a/..", fn () => OS.Path.joinDirFile {dir = "a", file = ".."})
  (* "If the string file does not correspond to an arc, raises InvalidArc." *)
  val () = T.raises ("OS.Path.joinDirFile/path-as-file-InvalidArc", isInvalidArc,
                     fn () => OS.Path.joinDirFile {dir = "a", file = "b/c"})
  val () = T.raises ("OS.Path.joinDirFile/root-as-file-InvalidArc", isInvalidArc,
                     fn () => OS.Path.joinDirFile {dir = "a", file = "/"})

  (* ---- splitBaseExt, base, ext: the table ---- *)
  val splitBaseExtTable =
    [("", {base = "", ext = NONE}), (".login", {base = ".login", ext = NONE}),
     ("/.login", {base = "/.login", ext = NONE}), ("a", {base = "a", ext = NONE}),
     ("a.", {base = "a.", ext = NONE}), ("a.b", {base = "a", ext = SOME "b"}),
     ("a.b.c", {base = "a.b", ext = SOME "c"}), (".news/comp", {base = ".news/comp", ext = NONE})]
  val () = List.app (fn (p, e) => T.eq showBaseExt ("OS.Path.splitBaseExt/row-" ^ enc p, e,
                                                    fn () => OS.Path.splitBaseExt p))
                    splitBaseExtTable
  val () = List.app (fn (p, {base, ext}) => eqS ("OS.Path.base/row-" ^ enc p, base, fn () => OS.Path.base p))
                    splitBaseExtTable
  val () = List.app (fn (p, {base, ext}) => T.eq (T.option T.string) ("OS.Path.ext/row-" ^ enc p, ext,
                                                                       fn () => OS.Path.ext p))
                    splitBaseExtTable
  (* "a non-empty sequence of characters following the right-most,
     non-initial, occurrence of "." in the last arc" *)
  val () = T.eq showBaseExt ("OS.Path.splitBaseExt/only-the-last-arc", {base = "a.b/c", ext = NONE},
                             fn () => OS.Path.splitBaseExt "a.b/c")
  val () = T.eq showBaseExt ("OS.Path.splitBaseExt/dot-in-directory", {base = "/a.b/c", ext = SOME "d"},
                             fn () => OS.Path.splitBaseExt "/a.b/c.d")
  val () = T.eq showBaseExt ("OS.Path.splitBaseExt/initial-dot-of-last-arc", {base = "a/.b", ext = NONE},
                             fn () => OS.Path.splitBaseExt "a/.b")
  val () = T.eq showBaseExt ("OS.Path.splitBaseExt/second-dot-of-last-arc", {base = "a/.", ext = SOME "b"},
                             fn () => OS.Path.splitBaseExt "a/..b")
  val () = T.eq showBaseExt ("OS.Path.splitBaseExt/parent-arc", {base = "a/..", ext = NONE},
                             fn () => OS.Path.splitBaseExt "a/..")
  val () = T.eq showBaseExt ("OS.Path.splitBaseExt/trailing-separator", {base = "a.b/", ext = NONE},
                             fn () => OS.Path.splitBaseExt "a.b/")
  (* "The base part is everything to the left of the extension except the
     final "."": empty arcs included. *)
  val () = T.eq showBaseExt ("OS.Path.splitBaseExt/empty-arc", {base = "a//c", ext = SOME "d"},
                             fn () => OS.Path.splitBaseExt "a//c.d")
  val () = T.eq showBaseExt ("OS.Path.splitBaseExt/root-empty-arc", {base = "//c", ext = SOME "d"},
                             fn () => OS.Path.splitBaseExt "//c.d")

  (* ---- joinBaseExt: "a left inverse of splitBaseExt"; SOME "" is NONE ---- *)
  val () = List.app (fn (p, be) => eqS ("OS.Path.joinBaseExt/row-" ^ enc p, p, fn () => OS.Path.joinBaseExt be))
                    splitBaseExtTable
  val () = eqS ("OS.Path.joinBaseExt/SOME", "a.b", fn () => OS.Path.joinBaseExt {base = "a", ext = SOME "b"})
  val () = eqS ("OS.Path.joinBaseExt/NONE", "a", fn () => OS.Path.joinBaseExt {base = "a", ext = NONE})
  val () = eqS ("OS.Path.joinBaseExt/SOME-empty-is-NONE", "a", fn () => OS.Path.joinBaseExt {base = "a", ext = SOME ""})
  val () = eqS ("OS.Path.joinBaseExt/path-base", "/x/y.tar.gz",
                fn () => OS.Path.joinBaseExt {base = "/x/y.tar", ext = SOME "gz"})
  (* "The opposite does not hold, since the extension may be empty, or may
     contain extension separators." *)
  val () = T.eq showBaseExt ("OS.Path.joinBaseExt/not-a-right-inverse", {base = "a.b", ext = SOME "c"},
                             fn () => OS.Path.splitBaseExt (OS.Path.joinBaseExt {base = "a", ext = SOME "b.c"}))

  (* ---- mkCanonical, isCanonical ---- *)
  (* "Redundant occurrences of the parent arc, the current arc, and the empty
     arc are removed. The canonical path will never be the empty string; the
     empty path is converted to the current directory path" *)
  val () = List.app (fn (p, e) => eqS ("OS.Path.mkCanonical/" ^ enc p, e, fn () => OS.Path.mkCanonical p))
                    [("", "."), (".", "."), ("./", "."), ("a", "a"), ("a/", "a"), ("./a//b/", "a/b"),
                     ("a/./b", "a/b"), ("a/../b", "b"), ("a/..", "."), ("a/b/../..", "."), ("../x", "../x"),
                     ("a/../../b", "../b"), ("../../a/b/c", "../../a/b/c"), ("/a/b/../c", "/a/c"),
                     ("//a", "/a"), ("/a/", "/a"), ("/", "/"), ("/a/./b/", "/a/b"), ("/../a", "/a")]
  (* "Some examples of canonical paths, using Unix syntax, are as follows" *)
  val () = List.app (fn p => eqB ("OS.Path.isCanonical/example-" ^ enc p, true, fn () => OS.Path.isCanonical p))
                    [".", "/", "a", "a/b/c", "..", "../a", "../../a/b/c", "/a/b/c"]
  (* The list has "/." as well, although "Redundant occurrences of ... the
     current arc ... are removed" makes it the root "/", which is canonical
     too (every system of the matrix takes this reading). The two readings
     agree that mkCanonical gives one of the two, and that "/." is canonical
     exactly when mkCanonical keeps it. *)
  val () = eqB ("OS.Path.isCanonical/example-root-current-arc", true,
                fn () => let val c = OS.Path.mkCanonical "/."
                         in (c = "/" orelse c = "/.") andalso OS.Path.isCanonical "/." = (c = "/.") end)
  (* "no occurrences of the empty arc, no occurrences of the current arc
     unless the current arc is the only arc in the path, and contains parent
     arcs only at the beginning and only if the path is relative" *)
  val () = List.app (fn p => eqB ("OS.Path.isCanonical/not-" ^ enc p, false, fn () => OS.Path.isCanonical p))
                    ["", "./a", "a/", "a//b", "a/./b", "a/..", "a/../b", "/..", "/a/", "../a/..", "//"]
  (* "Syntactically, two paths can be checked for equality by applying string
     equality to canonical versions of the paths." *)
  val () = eqB ("OS.Path.mkCanonical/equality-of-paths", true,
                fn () => OS.Path.mkCanonical "a/./b/" = OS.Path.mkCanonical "a//c/../b"
                         andalso OS.Path.mkCanonical "a/b" <> OS.Path.mkCanonical "b/a")

  (* ---- mkAbsolute: "If path is already absolute, it is returned unchanged.
     Otherwise, the function returns the canonical concatenation of
     relativeTo with path" ---- *)
  fun absolute (p, r) = OS.Path.mkAbsolute {path = p, relativeTo = r}
  val () = List.app (fn (p, r, e) => eqS ("OS.Path.mkAbsolute/" ^ enc p ^ "-to-" ^ enc r, e, fn () => absolute (p, r)))
                    [("a", "/b", "/b/a"), ("../c", "/a/b", "/a/c"), (".", "/a", "/a"), ("a/./b/", "/x", "/x/a/b"),
                     ("", "/a", "/a"), ("b", "/a/../c", "/c/b"), ("/x/../y", "/a", "/x/../y"), ("/", "/a", "/")]
  (* "If relativeTo is not absolute ... the Path exception is raised." *)
  val () = T.raises ("OS.Path.mkAbsolute/relativeTo-relative-Path", isPath, fn () => absolute ("a", "b"))
  val () = T.raises ("OS.Path.mkAbsolute/relativeTo-empty-Path", isPath, fn () => absolute ("a", ""))

  (* ---- mkRelative: the table ---- *)
  fun relative (p, r) = OS.Path.mkRelative {path = p, relativeTo = r}
  val mkRelativeTable =
    [("a/b", "/c/d", "a/b"), ("/", "/a/b/c", "../../.."), ("/a/b/", "/a/c", "../b/"), ("/a/b", "/a/c", "../b"),
     ("/a/b/", "/a/c/", "../b/"), ("/a/b", "/a/c/", "../b"), ("/", "/", "."), ("/", "/.", "."), ("/", "/..", "."),
     ("/a/b/../c", "/a/d", "../b/../c"), ("/a/b", "/c/d", "../../a/b"), ("/c/a/b", "/c/d", "../a/b"),
     ("/c/d/a/b", "/c/d", "a/b")]
  val () = List.app (fn (p, r, e) => eqS ("OS.Path.mkRelative/row-" ^ enc p ^ "-to-" ^ enc r, e, fn () => relative (p, r)))
                    mkRelativeTable
  (* "If path is relative, it is returned unchanged." "If path and abs are
     equal, then the current arc is the result." *)
  val () = eqS ("OS.Path.mkRelative/relative-unchanged", "a/../b", fn () => relative ("a/../b", "/c"))
  val () = eqS ("OS.Path.mkRelative/equal", ".", fn () => relative ("/a/b", "/a/b"))
  val () = eqS ("OS.Path.mkRelative/equal-to-canonical", ".", fn () => relative ("/a/b", "/a/./b/"))
  val () = eqS ("OS.Path.mkRelative/below", "b/c", fn () => relative ("/a/b/c", "/a"))
  val () = eqS ("OS.Path.mkRelative/above", "../..", fn () => relative ("/a", "/a/b/c"))
  (* "If relativeTo is not absolute ... the Path exception is raised." *)
  val () = T.raises ("OS.Path.mkRelative/relativeTo-relative-Path", isPath, fn () => relative ("/a", "b"))
  val () = T.raises ("OS.Path.mkRelative/relativeTo-empty-Path", isPath, fn () => relative ("/a", ""))

  (* ---- isAbsolute, isRelative: the Unix examples of the text ---- *)
  val () = List.app (fn (p, abs) => eqB ("OS.Path.isAbsolute/" ^ enc p, abs, fn () => OS.Path.isAbsolute p))
                    [("/", true), ("/a/b", true), ("//a", true), ("/..", true),
                     ("..", false), ("a/b", false), ("", false), (".", false), ("\\a", false), ("a/", false)]
  val () = List.app (fn (p, rel) => eqB ("OS.Path.isRelative/" ^ enc p, rel, fn () => OS.Path.isRelative p))
                    [("/", false), ("/a/b", false), ("//a", false),
                     ("..", true), ("a/b", true), ("", true), (".", true), ("\\a", true), ("a/", true)]

  (* ---- isRoot: "true if path is a canonical specification of a root
     directory" ---- *)
  val () = List.app (fn (p, root) => eqB ("OS.Path.isRoot/" ^ enc p, root, fn () => OS.Path.isRoot p))
                    [("/", true), ("", false), (".", false), ("..", false), ("a", false), ("/a", false),
                     ("//", false), ("/a/..", false), ("/..", false)]

  (* ---- concat: "the path consisting of path followed by t"; "a trailing
     empty arc in the first argument is dropped" ---- *)
  val () = List.app (fn (p, t, e) => eqS ("OS.Path.concat/" ^ enc p ^ "-and-" ^ enc t, e, fn () => OS.Path.concat (p, t)))
                    [("a/b", "../c", "a/b/../c"), ("a", "b", "a/b"), ("/a", "b/c", "/a/b/c"), ("a/", "b", "a/b"),
                     ("/", "a", "/a"), ("", "a", "a"), ("a", "", "a"), ("a//", "b", "a//b"), ("a", "b/", "a/b/"),
                     ("a", "..", "a/.."), ("..", "a", "../a"), ("/a/", "./b", "/a/./b")]
  (* "It raises the exception Path if t is not a relative path" *)
  val () = T.raises ("OS.Path.concat/absolute-second-Path", isPath, fn () => OS.Path.concat ("a", "/b"))
  val () = T.raises ("OS.Path.concat/root-second-Path", isPath, fn () => OS.Path.concat ("/a", "/"))

  (* ---- fromUnixPath, toUnixPath: the syntax of the host is that of Unix ---- *)
  val unixPaths = ["", "/", "a", "a/b", "/a/../b/", "..", ".", "a//b", "/.login"]
  val () = List.app (fn p => eqS ("OS.Path.fromUnixPath/" ^ enc p, p, fn () => OS.Path.fromUnixPath p)) unixPaths
  val () = List.app (fn p => eqS ("OS.Path.toUnixPath/" ^ enc p, p, fn () => OS.Path.toUnixPath p)) unixPaths

  (* ---- the exceptions ---- *)
  val () = T.raises ("OS.Path.Path/raise-handle", isPath, fn () => raise OS.Path.Path)
  val () = T.raises ("OS.Path.InvalidArc/raise-handle", isInvalidArc, fn () => raise OS.Path.InvalidArc)
  val () = eqB ("OS.Path.Path/is-not-InvalidArc", false, fn () => (raise OS.Path.Path) handle OS.Path.InvalidArc => true
                                                                                    | _ => false)
  val () = eqB ("OS.Path.InvalidArc/is-not-Path", false, fn () => (raise OS.Path.InvalidArc) handle OS.Path.Path => true
                                                                                           | _ => false)

  (* ---- laws on pseudo-random paths ---- *)
  (* randomPath (): a string of arcs from a small set, with or without a
     root; randomArcs (): a list of arcs, the empty one included. *)
  val arcPool = ["a", "b", "..", ".", "", "c.d", "e."]
  fun randomArcs () = List.tabulate (T.range (0, 4), fn _ => T.oneOf arcPool)
  fun randomPath () = String.concatWith "/" ((if T.range (0, 2) = 0 then [""] else []) @ randomArcs ())
  fun forAll (n, gen, prop) = let fun go 0 = true | go k = prop (gen ()) andalso go (k - 1) in go n end
  val () = T.seed 1917

  val () = eqB ("OS.Path.toString/inverts-fromString-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.toString (OS.Path.fromString p) = p))
  (* "fromString o toString is also the identity, provided no exception is
     raised": the absolute path without arcs, which no string gives, is left
     out. *)
  fun randomParts () =
    let val isAbs = T.range (0, 1) = 0 val arcs = randomArcs ()
    in if isAbs andalso List.null arcs then {isAbs = true, vol = "", arcs = ["a"]} else {isAbs = isAbs, vol = "", arcs = arcs} end
  val () = eqB ("OS.Path.fromString/inverts-toString-random", true,
                fn () => forAll (300, randomParts,
                                 fn parts => (OS.Path.fromString (OS.Path.toString parts) = parts) handle OS.Path.Path => true))
  val () = eqB ("OS.Path.toString/relative-is-relative-random", true,
                fn () => forAll (300, randomArcs,
                                 fn arcs => OS.Path.isRelative (OS.Path.toString {isAbs = false, vol = "", arcs = arcs})
                                            handle OS.Path.Path => (case arcs of "" :: _ => true | _ => false)))
  val () = eqB ("OS.Path.isAbsolute/not-isRelative-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.isAbsolute p <> OS.Path.isRelative p))
  val () = eqB ("OS.Path.mkCanonical/is-canonical-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.isCanonical (OS.Path.mkCanonical p)))
  val () = eqB ("OS.Path.mkCanonical/never-empty-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.mkCanonical p <> ""))
  val () = eqB ("OS.Path.mkCanonical/keeps-isAbsolute-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.isAbsolute (OS.Path.mkCanonical p) = OS.Path.isAbsolute p))
  (* "It is equivalent to (path = mkCanonical path)." *)
  val () = eqB ("OS.Path.isCanonical/is-mkCanonical-equality-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.isCanonical p = (p = OS.Path.mkCanonical p)))
  val () = eqB ("OS.Path.dir/is-splitDirFile-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.dir p = #dir (OS.Path.splitDirFile p)))
  val () = eqB ("OS.Path.file/is-splitDirFile-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.file p = #file (OS.Path.splitDirFile p)))
  val () = eqB ("OS.Path.splitDirFile/file-is-last-arc-random", true,
                fn () => forAll (300, randomPath,
                                 fn p => case List.rev (#arcs (OS.Path.fromString p)) of
                                           [] => OS.Path.file p = ""
                                         | last :: _ => OS.Path.file p = last))
  val () = eqB ("OS.Path.base/is-splitBaseExt-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.base p = #base (OS.Path.splitBaseExt p)))
  val () = eqB ("OS.Path.ext/is-splitBaseExt-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.ext p = #ext (OS.Path.splitBaseExt p)))
  (* "splitBaseExt will never return the extension SOME("")" *)
  val () = eqB ("OS.Path.splitBaseExt/never-SOME-empty-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.ext p <> SOME ""))
  val () = eqB ("OS.Path.joinBaseExt/inverts-splitBaseExt-random", true,
                fn () => forAll (300, randomPath, fn p => OS.Path.joinBaseExt (OS.Path.splitBaseExt p) = p))
  (* concat as the page's implementation: the arcs of the second path after
     those of the first without its trailing empty arc. *)
  fun concatArcs ([], l) = l
    | concatArcs ([""], l) = l
    | concatArcs (a :: r, l) = a :: concatArcs (r, l)
  fun randomRelative () = String.concatWith "/" (List.tabulate (T.range (1, 3), fn _ => T.oneOf ["a", "b", "..", "."]))
  val () = eqB ("OS.Path.concat/arcs-random", true,
                fn () => forAll (300, fn () => (randomPath (), randomRelative ()),
                                 fn (p, t) => let val {isAbs, vol, arcs} = OS.Path.fromString p
                                              in OS.Path.fromString (OS.Path.concat (p, t))
                                                 = {isAbs = isAbs, vol = vol,
                                                    arcs = concatArcs (arcs, #arcs (OS.Path.fromString t))}
                                              end))
  (* "if path is canonical, then the result of getParent will also be
     canonical"; the same for mkAbsolute and mkRelative ("Thus, if path and
     relativeTo are canonical, the result will be canonical", "Note that if
     both paths are canonical, then the result will be canonical"). *)
  fun canonical () = OS.Path.mkCanonical (randomPath ())
  fun canonicalAbsolute () = OS.Path.mkCanonical ("/" ^ randomRelative ())
  val () = eqB ("OS.Path.getParent/keeps-canonical-random", true,
                fn () => forAll (300, canonical, fn p => OS.Path.isRoot p orelse OS.Path.isCanonical (OS.Path.getParent p)))
  val () = eqB ("OS.Path.mkRelative/keeps-canonical-random", true,
                fn () => forAll (300, fn () => (canonicalAbsolute (), canonicalAbsolute ()),
                                 fn (p, r) => OS.Path.isCanonical (relative (p, r))))
  val () = eqB ("OS.Path.mkAbsolute/keeps-canonical-random", true,
                fn () => forAll (300, fn () => (canonical (), canonicalAbsolute ()),
                                 fn (p, r) => OS.Path.isCanonical (absolute (p, r))))
  (* mkRelative p r, taken relative to r, "is equivalent to the path path":
     for canonical paths with at least one arc below the root, mkAbsolute
     gives p back. *)
  fun deepAbsolute () = OS.Path.mkCanonical ("/" ^ T.oneOf ["a", "b"] ^ "/" ^ randomRelative ())
  fun rooted () = let val p = deepAbsolute () in if OS.Path.isRoot p then "/a" else p end
  val () = eqB ("OS.Path.mkAbsolute/inverts-mkRelative-random", true,
                fn () => forAll (300, fn () => (rooted (), canonicalAbsolute ()),
                                 fn (p, r) => absolute (relative (p, r), r) = p))
  val () = eqB ("OS.Path.mkRelative/is-relative-random", true,
                fn () => forAll (300, fn () => (rooted (), canonicalAbsolute ()),
                                 fn (p, r) => OS.Path.isRelative (relative (p, r))))
end
