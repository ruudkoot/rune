# MLKit 4.7.23: `OS.Path.splitBaseExt` drops an empty arc from the base: `"a//c.d"` gives the base `"a/c"`

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** MLton and SML/NJ also drop the empty arc; Poly/ML keeps it.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Path.sml` as the tag `v4.7.23`, byte for
byte, so the code below is unchanged there; `master` was not built.
MLton and SML/NJ do the same (Rune's `tests/basis/deviations.txt` records
it for both).

## Summary

* **The trigger:** `OS.Path.splitBaseExt` (and `base`) of a path with an
  extension whose directory part ends with an empty arc, such as
  `"a//c.d"` or `"//c.d"`.
* **What goes wrong:** the base leaves out the empty arc: `"a/c"` and
  `"/c"` instead of `"a//c"` and `"//c"`. So `joinBaseExt (splitBaseExt
  p)` is not `p`.
* **Required behaviour:** the
  [`OS_PATH` specification](https://smlfamily.github.io/Basis/os-path.html):
  "`splitBaseExt path` splits the path path into its base and extension
  parts. The extension is a non-empty sequence of characters following the
  right-most, non-initial, occurrence of "." in the last arc; NONE is
  returned if the extension is not defined. The base part is everything to
  the left of the extension except the final "."."

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
(* splitBaseExt of paths with an empty arc before the last one *)
fun q s = "\"" ^ s ^ "\""
fun showBE {base, ext} = "{base = " ^ q base ^ ", ext = " ^ (case ext of NONE => "NONE" | SOME e => "SOME " ^ q e) ^ "}"
val () = List.app (fn p => print ("splitBaseExt " ^ q p ^ " = " ^ showBE (OS.Path.splitBaseExt p) ^ "\n"))
                  ["a//c.d", "//c.d", "a/b.c"]
val () = print ("joinBaseExt (splitBaseExt \"a//c.d\") = " ^ q (OS.Path.joinBaseExt (OS.Path.splitBaseExt "a//c.d")) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
splitBaseExt "a//c.d" = {base = "a/c", ext = SOME "d"}
splitBaseExt "//c.d" = {base = "/c", ext = SOME "d"}
splitBaseExt "a/b.c" = {base = "a/b", ext = SOME "c"}
joinBaseExt (splitBaseExt "a//c.d") = "a/c.d"
```

Expected: the bases `"a//c"`, `"//c"` and `"a/b"`, and `"a//c.d"`.

## The cause

`splitBaseExt` (`basis/Path.sml`, lines 185-198) splits the path into
directory and file, and joins the directory with the file's base:

```sml
  fun splitBaseExt s =
      let val {dir, file} = splitDirFile s
	  open Substring
	  val (fst, snd) = splitr (fn c => c <> #".") (full file)
      in
	  if isEmpty snd         (* dot at right end     *)
	     orelse isEmpty fst  (* no dot               *)
	     orelse size fst = 1 (* dot at left end only *)
	      then {base = s, ext = NONE}
	  else
	      {base = joinDirFile{dir = dir,
				  file = string (trimr 1 fst)},
	       ext = SOME (string snd)}
      end;
```

`splitDirFile "a//c.d"` is `{dir = "a/", file = "c.d"}`, and
`joinDirFile {dir = "a/", file = "c"}` is `"a/c"` (it goes through
`concat`, which drops the trailing slash of `dir`), so the round trip
loses the empty arc.

## The fix

The last arc is the end of the path, so the base is the path without the
extension and its dot:

```diff
--- a/basis/Path.sml
+++ b/basis/Path.sml
@@ -185,7 +185,7 @@
   fun splitBaseExt s =
-      let val {dir, file} = splitDirFile s
+      let val {file, ...} = splitDirFile s
 	  open Substring
 	  val (fst, snd) = splitr (fn c => c <> #".") (full file)
       in
@@ -194,8 +194,8 @@
 	     orelse size fst = 1 (* dot at left end only *)
 	      then {base = s, ext = NONE}
 	  else
-	      {base = joinDirFile{dir = dir,
-				  file = string (trimr 1 fst)},
+	      (* file is the end of s: the base is s without "." ^ ext *)
+	      {base = String.substring (s, 0, String.size s - size snd - 1),
 	       ext = SOME (string snd)}
       end;
```

Tested on a copy of the installed `lib/mlkit` with this change (together
with the fix of `concat`, report `OS.Path.concat/empty-second-path`, and
the changes proposed in the other reports of this series, which touch
other functions): `bug.sml` then prints the bases `"a//c"`, `"//c"` and
`"a/b"` and the path `"a//c.d"`, and Rune's `tests/basis/os.path.sml`
passes (293 checks). `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks this (`tests/basis/os.path.sml`,
`OS.Path.splitBaseExt/empty-arc`, `OS.Path.splitBaseExt/root-empty-arc`,
and `OS.Path.joinBaseExt/inverts-splitBaseExt-random` on random paths).
The lines of `tests/basis/deviations.txt`, worded as the ones for MLton
and SML/NJ:

```
native:mlkit@* | OS.Path.splitBaseExt/*empty-arc | HOST-BUG | the base that splitBaseExt returns leaves out empty arcs: splitBaseExt "a//c.d" is {base = "a/c", ext = SOME "d"}, not "a//c" ("everything to the left of the extension except the final "."")
native:mlkit@* | OS.Path.joinBaseExt/inverts-splitBaseExt-random | HOST-BUG | joinBaseExt o splitBaseExt is not the identity on a path with an empty arc, which splitBaseExt drops from the base ("a//c.d" gives base "a/c")
```
