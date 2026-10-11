# SML/NJ 110.99.9 and 2026.2: `OS.Path.splitBaseExt` and `joinBaseExt` drop an empty arc before the last one: `splitBaseExt "//"` has the base `"/"`

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on
`splitBaseExt` or `joinBaseExt` (searched 2026-10-11). `os-path-fn.sml` is
the same in 110.99.9, in smlnj/legacy at `6ed5a0a` (2026-09-13) and in
smlnj/smlnj at `17362d2` (2026-09-24), so 2026.3 has it too (by reading the
code).

**What is worth sending SML/NJ:** a new issue on smlnj/legacy, with
`bug.sml` and `fix.diff` (`upstream.md` is the text).

## Summary

* **The trigger:** `OS.Path.splitBaseExt p` (and so `base p`) where the
  arc before the last one is empty, that is where `p` has `//` before its
  last arc: `"//"`, `"a//b"`, `"a//c.d"`; and `joinBaseExt {base, ext =
  SOME e}` where `base` has such an arc.
* **What goes wrong:** the empty arc is lost:
  - `splitBaseExt "//"` is `{base = "/", ext = NONE}`, and `"a//b"` gives
    the base `"a/b"`: with no extension the base is not even the path;
  - `splitBaseExt "a//c.d"` is `{base = "a/c", ext = SOME "d"}`;
  - `joinBaseExt {base = "a//c", ext = SOME "d"}` is `"a/c.d"`.

  So `joinBaseExt (splitBaseExt p)` is not `p`.
* **Required behaviour:** the
  [Basis `OS_PATH` specification](https://smlfamily.github.io/Basis/os-path.html#SIG:OS_PATH.splitBaseExt:VAL):
  for `splitBaseExt`, "The base part is everything to the left of the
  extension except the final "."", and of `joinBaseExt`: "It is a left
  inverse of `splitBaseExt`, i.e., `joinBaseExt o splitBaseExt` is the
  identity." Poly/ML and Rune get every line of `bug.sml` right. MLton and
  MLKit keep the path when there is no extension and join right, but drop
  the arc from the base when there is an extension (MLKit's report
  `docs/bugreport/mlkit/OS.Path.splitBaseExt/empty-arc-dropped`).

## Where it happens

| Build | wrong of 8 |
|---|---|
| 110.99.9, 64-bit | 6 |
| 110.99.9, 32-bit | 6 |
| 2026.2 (64-bit) | 6 |
| `fix.diff`, as a standalone copy (`fix-check.sml`) | 0 (`joinBaseExt (splitBaseExt p) = p` for all 21,845 paths tried) |

```
$ sml bug.sml                           # 110.99.9 (32 or 64 bits) or 2026.2
splitBaseExt "//" = {base = "/", ext = NONE}, expected {base = "//", ext = NONE}: WRONG
splitBaseExt "a//b" = {base = "a/b", ext = NONE}, expected {base = "a//b", ext = NONE}: WRONG
splitBaseExt "a//c.d" = {base = "a/c", ext = SOME "d"}, expected {base = "a//c", ext = SOME "d"}: WRONG
splitBaseExt "//c.d" = {base = "/c", ext = SOME "d"}, expected {base = "//c", ext = SOME "d"}: WRONG
splitBaseExt "a/b.c" = {base = "a/b", ext = SOME "c"}, expected {base = "a/b", ext = SOME "c"}: ok
joinBaseExt {base = "a//c", ext = SOME "d"} = "a/c.d", expected "a//c.d": WRONG
joinBaseExt {base = "a//", ext = SOME "d"} = "a/.d", expected "a//.d": WRONG
joinBaseExt {base = "a/b", ext = SOME "c"} = "a/b.c", expected "a/b.c": ok
```

## The cause

`base/system/Basis/Implementation/OS/os-path-fn.sml` builds the base with
`joinDirFile` from the parts of `splitDirFile`, and `joinBaseExt` takes the
base apart with `splitDirFile` and joins it again:

```sml
    fun splitBaseExt p = let
	  val {dir, file} = splitDirFile p
	  ...
	  in
	    {base = joinDirFile{dir=dir, file=file}, ext = ext}
	  end
    fun joinBaseExt {base, ext=NONE} = base
      | joinBaseExt {base, ext=SOME ""} = base
      | joinBaseExt {base, ext=SOME ext} = let
	  val {dir, file} = splitDirFile base
	  in
	    joinDirFile{dir=dir, file=String.concat[file, ".", ext]}
	  end
```

`splitDirFile "a//c.d"` is `{dir = "a/", file = "c.d"}`: the directory's
arcs are `["a", ""]`. `joinDirFile` appends the file with `concatArcs`,
which drops a trailing empty arc of the directory ("like `List.@`, except
that a trailing empty arc in the first argument is dropped"), so
`["a", ""] @ ["c"]` becomes `a/c`. For `"//"` the directory is `"/"` and
the file `""`, and `joinDirFile {dir = "/", file = ""}` is `"/"`.

## The fix

The last arc is the end of the path, so neither function needs to take the
path apart: the base is the path without the extension and its dot, and
`joinBaseExt` appends to the base. `fix.diff` (against smlnj/legacy
`6ed5a0a`; it also applies to 110.99.9, and to smlnj/smlnj with
`git apply -p2`) does that, and keeps the checks that `joinDirFile` made:
`splitDirFile` still checks the directory's arcs, and `checkArc` the file
part (without the extension, as before) and the joined arc, so `InvalidArc`
is raised where it was. Where the path has no empty arc to lose, nothing
changes on Unix. On Windows the base keeps the path's own separators,
where `joinDirFile` wrote `\` (`splitBaseExt "a/b.c"` gave the base `a\b`);
that too is what `joinBaseExt o splitBaseExt` being the identity asks.

**How it was tested:** SML/NJ was not rebuilt. `fix-check.sml` holds the
patched functions, copied into a standalone program on top of `OS.Path`'s
`splitDirFile`, with the Unix `checkArc`. It tries every path of up to 7
characters from `a`, `.`, `/` and NUL (21,845 paths) on 110.99.9 (32 and 64
bits) and 2026.2:
* `joinBaseExt (splitBaseExt p) = p` for all of them that `splitBaseExt`
  accepts;
* on the 15,989 paths without `//`, `splitBaseExt` gives what `OS.Path`'s
  gives, `InvalidArc` included, and so does `joinBaseExt` with six
  extensions (`NONE`, `""`, `"b"`, `"b.c"`, `"/"` and NUL).

Windows was not tried.

## How Rune met it

By the laws of Rune's Basis Library documentation: each `Law:` is tested
on generated values, and `tests/basis/run-laws-hosts.py` runs them against
the Basis Library of the other compilers (`docs/plans/quickcheck-hunt.md`,
the sections on the other compilers). The law of `splitBaseExt`
(`lib/basis/sig_os_path.sml`), `joinBaseExt (splitBaseExt p) = p` for
generated paths, fails on SML/NJ at `"//"`; it is the line
`native:smlnj* | OS_PATH.splitBaseExt/law-1@OS.Path` of
`tests/basis/law-deviations.txt`. Rune's Basis suite had the case with an
extension (`OS.Path.splitBaseExt/*empty-arc` and
`OS.Path.joinBaseExt/inverts-splitBaseExt-random` in
`tests/basis/deviations.txt`, for SML/NJ, MLton and MLKit).
