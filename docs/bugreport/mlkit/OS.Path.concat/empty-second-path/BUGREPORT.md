# MLKit 4.7.23: `OS.Path.concat (p, "")` adds an empty arc: `concat ("a", "")` is `"a/"`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton, SML/NJ and Poly/ML give `"a"`.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Path.sml` as the tag `v4.7.23`, byte for
byte, so the code below is unchanged there; `master` was not built.

## Summary

* **The trigger:** `OS.Path.concat (path, "")`, where `path` is not
  empty.
* **What goes wrong:** the result ends with a slash, a path with one more
  arc, the empty one: `concat ("a", "")` is `"a/"`, whose arcs are
  `["a", ""]`.
* **Required behaviour:** the
  [`OS_PATH` specification](https://smlfamily.github.io/Basis/os-path.html):
  "`concat (path, t)` returns the path consisting of path followed by t."
  The empty path has no arcs (`fromString ""` is `{isAbs = false, vol =
  "", arcs = []}`), so `"a"` followed by it is `"a"`. The implementation
  the page gives, `toString {isAbs=isAbs, vol=v1, arcs=concatArcs(al1,
  al2)}` "where concatArcs is like List.@, except that a trailing empty
  arc in the first argument is dropped", gives `"a"` too.

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM (kernel
  6.18.44), running as root.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* concat (p, "") and the arcs of the result *)
fun q s = "\"" ^ s ^ "\""
fun arcs p = "[" ^ String.concatWith ", " (map q (#arcs (OS.Path.fromString p))) ^ "]"
val () = List.app (fn (a, b) => let val c = OS.Path.concat (a, b)
                                in print ("concat (" ^ q a ^ ", " ^ q b ^ ") = " ^ q c ^ ", arcs " ^ arcs c ^ "\n") end)
                  [("a", ""), ("/a", ""), ("a/b", ""), ("a", "b")]
val () = print ("joinDirFile {dir = \"b\", file = \"\"} = " ^ q (OS.Path.joinDirFile {dir = "b", file = ""}) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
concat ("a", "") = "a/", arcs ["a", ""]
concat ("/a", "") = "/a/", arcs ["a", ""]
concat ("a/b", "") = "a/b/", arcs ["a", "b", ""]
concat ("a", "b") = "a/b", arcs ["a", "b"]
joinDirFile {dir = "b", file = ""} = "b/"
```

Expected: `"a"`, `"/a"`, `"a/b"` and `"a/b"`. (The last line is right:
`joinDirFile` extends `"b"` with the empty arc; it is there because the
fix must keep it.)

## The cause

`concat` (`basis/Path.sml`, lines 84-97) always puts a slash between the
two paths:

```sml
	      case splitabsvolrest p1 of
		  (false, "",   "") => p2
		| (false, v,  path) => v ^ stripslash path ^ slash ^ p2
		| (true,  v,  ""  ) => v ^ volslash ^ p2
		| (true,  v,  path) => v ^ volslash ^ stripslash path ^ slash ^ p2
```

That is right when `p2` has arcs and wrong when it is empty. `joinDirFile`
(lines 162-163) is `concat (dir, file)`, and there the slash is wanted
even for the empty `file`, which is an arc.

## The fix

Keep the present function, under another name, for `joinDirFile`, and
handle the empty second path in `concat` (a trailing empty arc of the
first path is dropped, as `concatArcs` does):

```diff
--- a/basis/Path.sml
+++ b/basis/Path.sml
@@ -81,7 +81,8 @@
 	      raise Path
       end;
 
-  fun concat (p1, p2) =
+  (* p1 extended with p2, which may be the empty arc *)
+  fun extend (p1, p2) =
       let fun stripslash path =
 	      if isslash (path sub (size path - 1)) then
 		  substring(path, 0, SOME(size path - 1))
@@ -96,6 +97,13 @@
 		| (true,  v,  path) => v ^ volslash ^ stripslash path ^ slash ^ p2
       end;
 
+  (* the empty path has no arc: a trailing empty arc of p1 is dropped *)
+  fun concat (p1, "") =
+      if size p1 > 1 andalso isslash (p1 sub (size p1 - 1))
+      then substring (p1, 0, SOME (size p1 - 1))
+      else p1
+    | concat (p1, p2) = extend (p1, p2)
+
   fun getParent p =
       let open List
 	  val {isAbs, vol, arcs} = fromString p
@@ -160,7 +168,7 @@
   fun isCanonical p = mkCanonical p = p;
 
   fun joinDirFile {dir, file} =
-      if validArc file then concat(dir, file) else raise InvalidArc
+      if validArc file then extend(dir, file) else raise InvalidArc
 
   fun splitDirFile p =
       let open List
```

(`substring` is `String.extract` in this file.) Tested on a copy of the
installed `lib/mlkit` with this change (together with the fix of
`splitBaseExt`, report `OS.Path.splitBaseExt/empty-arc-dropped`, and the
changes proposed in the other reports of this series, which touch other
functions): `bug.sml` then prints `"a"`, `"/a"`, `"a/b"`, `"a/b"` and
`"b/"`, and Rune's `tests/basis/os.path.sml` passes (293 checks; a first
version of the fix that changed `concat` alone broke `joinDirFile {dir =
"b", file = ""}`, which the suite checks). `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks `concat` on a table of pairs
(`tests/basis/os.path.sml`, `OS.Path.concat/a-and-empty`: `got "a/",
expected "a"`). The line of `tests/basis/deviations.txt`:

```
native:mlkit@* | OS.Path.concat/a-and-empty | HOST-BUG | concat (p, "") adds an empty arc to p: concat ("a", "") is "a/", not "a" ("the path consisting of path followed by t", the empty path having no arcs)
```
