# MLKit 4.7.23: `IntInf.scan` does not skip vertical tab, form feed and carriage return

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** SML/NJ, from which MLKit's code comes, does not skip them either; MLton and Poly/ML skip all six.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same `basis/IntInf.sml` as 4.7.23 (the files are identical), so
the bug is not fixed there either.

## Summary

* **The trigger:** `IntInf.scan` (any radix) or `IntInf.fromString`
  (`LargeInt.scan`, `LargeInt.fromString`) on a string that starts with a
  vertical tab (`\v`), a form feed (`\f`) or a carriage return (`\r`)
  before the number.
* **What goes wrong:** the result is `NONE`: only space, tab and newline
  are skipped.
* **Required behaviour:** the
  [Basis `INTEGER` specification](https://smlfamily.github.io/Basis/integer.html)
  says `scan` parses the number "after skipping initial whitespace", and
  `fromString` "ignoring initial whitespace". Whitespace in the Basis
  Library is what `Char.isSpace` accepts ("space, newline, tab, carriage
  return, vertical tab, formfeed",
  [`CHAR`](https://smlfamily.github.io/Basis/char.html)), which is also
  what `StringCvt.skipWS` skips. MLKit's own `Int.scan` skips all six.

## Environment

* **MLKit:** v4.7.23 (`MLKit v4.7.23 (v4.7.23 - 2026-09-24T12:26:51+02:00)
  [X64 Backend]`), the official binary release `mlkit-bin-dist-linux.tgz`.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is standalone, built as
  `bug.mlb` (`$(SML_LIB)/basis/basis.mlb` and `bug.sml`) with
  `mlkit -o bug bug.mlb`.

## The program

`bug.sml`:

```sml
(* IntInf.scan and IntInf.fromString skip only space, tab and newline, not
   the other whitespace characters of Char.isSpace: vertical tab, form feed
   and carriage return.  Int.fromString, for contrast, skips all six. *)
fun opt NONE = "NONE"
  | opt (SOME s) = "SOME " ^ s
fun row (name, s) =
  print (name ^ ": IntInf.fromString = " ^ opt (Option.map IntInf.toString (IntInf.fromString s))
         ^ ", Int.fromString = " ^ opt (Option.map Int.toString (Int.fromString s)) ^ "\n")
val () = List.app row
  [("space          ", " 42"), ("tab            ", "\t42"), ("newline        ", "\n42"),
   ("vertical tab   ", "\v42"), ("form feed      ", "\f42"), ("carriage return", "\r42")]
```

```
$ mlkit -o bug bug.mlb
[reading source file:	bug.sml]
[wrote X64 code file:	MLB/RI_GC/bug.sml.s]
[wrote X64 code file:	MLB/RI_GC/base-link_objects.s]
[wrote executable file:	bug]
$ ./bug
space          : IntInf.fromString = SOME 42, Int.fromString = SOME 42
tab            : IntInf.fromString = SOME 42, Int.fromString = SOME 42
newline        : IntInf.fromString = SOME 42, Int.fromString = SOME 42
vertical tab   : IntInf.fromString = NONE, Int.fromString = SOME 42
form feed      : IntInf.fromString = NONE, Int.fromString = SOME 42
carriage return: IntInf.fromString = NONE, Int.fromString = SOME 42
```

## The cause

`IntInf.scan` (`basis/IntInf.sml`, code that "originates from SML/NJ")
skips whitespace with `NumScan.skipWS`, which skips a character whose code
in `cvtTable` is `wsCode` (128):

```sml
        fun skipWS (getc : (char, 'a) StringCvt.reader) cs = let
              fun skip cs = (case (getc cs)
		     of NONE => cs
		      | (SOME(c, cs')) => if (code c = wsCode) then skip cs' else cs
		    (* end case *))
```

The table gives 128 to tab (9), newline (10) and space (32) only; vertical
tab (11), form feed (12) and carriage return (13) are 255, "all other
characters":

```sml
          val cvtTable = "\
    	    \\255\255\255\255\255\255\255\255\255\128\128\255\255\255\255\255\
    	    \\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    	    \\128\255\255\255\255\255\255\255\255\255\255\129\255\130\131\255\
```

## The fix

Give characters 11, 12 and 13 the code of whitespace:

```diff
--- a/basis/IntInf.sml
+++ b/basis/IntInf.sml
@@ -71,7 +71,7 @@
        *)
         local
           val cvtTable = "\
-    	    \\255\255\255\255\255\255\255\255\255\128\128\255\255\255\255\255\
+    	    \\255\255\255\255\255\255\255\255\255\128\128\128\128\128\255\255\
     	    \\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
     	    \\128\255\255\255\255\255\255\255\255\255\255\129\255\130\131\255\
     	    \\000\001\002\003\004\005\006\007\008\009\255\255\255\255\255\255\
```

(`scanPrefix` does not skip whitespace since "mael 2005-12-13", so the
table's whitespace code matters only to `skipWS`: a whitespace character
after the sign or among the digits still ends the number.)

**Tested:** with this change applied to a copy of MLKit 4.7.23's library
(`SML_LIB` pointing at the copy), `bug.sml` prints `SOME 42` on all six
lines for `IntInf.fromString`, and the whitespace checks of the Rune test
programs `intinf_scan` and `intinf` (below) pass. Not tried against a
build of `master`.
The copy of the library had the fixes of the other reports of this
investigation applied as well (`Word.scan/0w-read-as-hex-prefix`,
`Word.fromLargeInt/Overflow-on-negative`, `IntInf.scan/*`,
`PackWord32Big.subVecX/no-sign-extension`, the `LargeIntVector` fix and
the runtime fix of `Int32.mod/SIGFPE-minInt-by-minus-one`); the Rune
programs were those the matrix compiled, `intn_word16` without its
`constants` section (`Int8.int/not-overloaded`).

## Relation to Rune

Rune's Basis Library suite (Rune at `3d83f11`) checks initial whitespace
in `tests/basis/fn/integer_fn.sml` (`fromString/whitespace-*`,
line 260-263) and `tests/basis/fn/integer_scan_fn.sml`
(`scan/DEC-whitespace-*`, line 85-87). For `IntInf` (`tests/basis/intinf.sml`,
`tests/basis/intinf_scan.sml`) the `all-six`, `vertical-tab`, `form-feed`
and `return` cases fail on MLKit. SML/NJ has the same bug (the
`native:smlnj*@*` lines of `tests/basis/deviations.txt` under `Int`). The
MLKit failures are explained by

```
native:mlkit@* | IntInf.*whitespace-[avfr]* | HOST-BUG | scan and fromString of IntInf skip space, tab and newline only, not vertical tab, form feed and carriage return
```
