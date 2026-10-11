# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `OS.Path.splitBaseExt` and `joinBaseExt` drop an empty arc before the last one (`splitBaseExt "//"` has the base `"/"`)

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | Any |
| System Component | Basis Library |
| Severity | Minor |
| Also present in the "development" version? | Yes: 2026.2 prints the same, and `os-path-fn.sml` of smlnj/smlnj `17362d2` is the same file |

### Description

When the arc before the last one is empty (a `//` before the last arc),
`OS.Path.splitBaseExt` loses it from the base, and `joinBaseExt` loses it
too:

* `splitBaseExt "//"` is `{base = "/", ext = NONE}`, and `"a//b"` gives the
  base `"a/b"`, although with no extension the base is the path;
* `splitBaseExt "a//c.d"` is `{base = "a/c", ext = SOME "d"}`;
* `joinBaseExt {base = "a//c", ext = SOME "d"}` is `"a/c.d"`.

The specification: the base "is everything to the left of the extension
except the final ".""; and "`joinBaseExt o splitBaseExt` is the identity".
Poly/ML gets every case right.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
splitBaseExt "//" = {base = "/", ext = NONE}, expected {base = "//", ext = NONE}: WRONG
splitBaseExt "a//b" = {base = "a/b", ext = NONE}, expected {base = "a//b", ext = NONE}: WRONG
splitBaseExt "a//c.d" = {base = "a/c", ext = SOME "d"}, expected {base = "a//c", ext = SOME "d"}: WRONG
splitBaseExt "//c.d" = {base = "/c", ext = SOME "d"}, expected {base = "//c", ext = SOME "d"}: WRONG
splitBaseExt "a/b.c" = {base = "a/b", ext = SOME "c"}, expected {base = "a/b", ext = SOME "c"}: ok
joinBaseExt {base = "a//c", ext = SOME "d"} = "a/c.d", expected "a//c.d": WRONG
joinBaseExt {base = "a//", ext = SOME "d"} = "a/.d", expected "a//.d": WRONG
joinBaseExt {base = "a/b", ext = SOME "c"} = "a/b.c", expected "a/b.c": ok
```

### Expected Behavior

The expected value of each line.

### Steps to Reproduce

```sml
(* OS.Path.splitBaseExt and joinBaseExt of paths with an empty arc before
   the last one. The specification: the base "is everything to the left of
   the extension except the final "."", and "joinBaseExt o splitBaseExt is
   the identity". Run: sml bug.sml *)
fun q s = "\"" ^ s ^ "\""
fun showBE {base, ext} =
      "{base = " ^ q base ^ ", ext = " ^ (case ext of NONE => "NONE" | SOME e => "SOME " ^ q e) ^ "}"
fun split (p, expected) =
      let val r = OS.Path.splitBaseExt p
      in print (concat ["splitBaseExt ", q p, " = ", showBE r, ", expected ", showBE expected, ": ",
                        if r = expected then "ok" else "WRONG", "\n"])
      end
fun join (be, expected) =
      let val r = OS.Path.joinBaseExt be
      in print (concat ["joinBaseExt ", showBE be, " = ", q r, ", expected ", q expected, ": ",
                        if r = expected then "ok" else "WRONG", "\n"])
      end
val () = split ("//", {base = "//", ext = NONE})
val () = split ("a//b", {base = "a//b", ext = NONE})
val () = split ("a//c.d", {base = "a//c", ext = SOME "d"})
val () = split ("//c.d", {base = "//c", ext = SOME "d"})
val () = split ("a/b.c", {base = "a/b", ext = SOME "c"})
val () = join ({base = "a//c", ext = SOME "d"}, "a//c.d")
val () = join ({base = "a//", ext = SOME "d"}, "a//.d")
val () = join ({base = "a/b", ext = SOME "c"}, "a/b.c")
val () = OS.Process.exit OS.Process.success
```

### Additional Information

`splitBaseExt` builds the base with `joinDirFile` from the parts of
`splitDirFile`, and `joinBaseExt` takes the base apart with `splitDirFile`
and joins it again. `joinDirFile` appends the file with `concatArcs`, which
drops a trailing empty arc of the directory: the directory of `"a//c.d"` is
`"a/"`, whose arcs are `["a", ""]`.

As the last arc is the end of the path, the patch takes the base as the
path without the extension and its dot, and has `joinBaseExt` append to the
base. It keeps the checks of `joinDirFile` (`InvalidArc` for a bad arc).
Where the path has no empty arc to lose, nothing changes on Unix; on
Windows the base keeps the path's own separators instead of `\`. It is
against legacy `main` (`6ed5a0a`) and also applies to 110.99.9 and, with
`-p2`, to smlnj/smlnj:

```diff
diff --git a/base/system/Basis/Implementation/OS/os-path-fn.sml b/base/system/Basis/Implementation/OS/os-path-fn.sml
index 9f8d281..d96a4a5 100644
--- a/base/system/Basis/Implementation/OS/os-path-fn.sml
+++ b/base/system/Basis/Implementation/OS/os-path-fn.sml
@@ -131,23 +131,31 @@ functor OS_PathFn (OSPathBase : sig
     fun dir p = #dir(splitDirFile p)
     fun file p = #file(splitDirFile p)
 
+  (* The base is the path up to the "." of the extension, and joinBaseExt
+   * appends to the base: going through joinDirFile would drop an empty arc
+   * before the last one (e.g., "a//b.c" would become "a/b.c").  The arcs are
+   * checked as joinDirFile checked them before.
+   *)
     fun splitBaseExt p = let
-	  val {dir, file} = splitDirFile p
+	  val {file, ...} = splitDirFile p
 	  val (file', ext') = SS.splitr (fn c => c <> #".") (SS.full file)
 	  val fileLen = SS.size file'
-	  val (file, ext) =
-		if (fileLen <= 1) orelse (SS.isEmpty ext')
-		  then (file, NONE)
-		  else (SS.string(SS.trimr 1 file'), SOME(SS.string ext'))
 	  in
-	    {base = joinDirFile{dir=dir, file=file}, ext = ext}
+	    if (fileLen <= 1) orelse (SS.isEmpty ext')
+	      then (ignore (checkArc file); {base = p, ext = NONE})
+	      else (
+		ignore (checkArc (SS.string(SS.trimr 1 file')));
+		{ base = SS.string(SS.trimr (SS.size ext' + 1) (SS.full p)),
+		  ext = SOME(SS.string ext')
+		})
 	  end
     fun joinBaseExt {base, ext=NONE} = base
       | joinBaseExt {base, ext=SOME ""} = base
       | joinBaseExt {base, ext=SOME ext} = let
-	  val {dir, file} = splitDirFile base
+	  val {file, ...} = splitDirFile base
 	  in
-	    joinDirFile{dir=dir, file=String.concat[file, ".", ext]}
+	    ignore (checkArc (String.concat[file, ".", ext]));
+	    String.concat[base, ".", ext]
 	  end
     fun base p = #base(splitBaseExt p)
     fun ext p = #ext(splitBaseExt p)
```

Not built: the patched functions, copied into a standalone program over
`OS.Path.splitDirFile`, give `joinBaseExt (splitBaseExt p) = p` for every
path of up to 7 characters from `a`, `.`, `/` and NUL, and agree with the
current ones, exceptions included, on all of those without `//` (110.99.9,
32 and 64 bits, and 2026.2).
