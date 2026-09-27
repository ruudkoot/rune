# MLKit 4.7.23: `Word.scan StringCvt.HEX` and `Word.fromString` read `0w12` as `0wx12`

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** Poly/ML also reads `0w12` as `0wx12`; MLton meets it.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same `basis/Word.sml`, `Word8.sml`, `Word31.sml`, `Word32.sml`,
`Word63.sml` and `Word64.sml` as 4.7.23 (the files are identical), so the
bug is not fixed there either.

## Summary

* **The trigger:** `scan StringCvt.HEX` or `fromString` of any word
  structure (`Word`, `Word8`, `Word16`, `Word31`, `Word32`, `Word63`,
  `Word64`, and so `LargeWord` and `SysWord`) on a string that starts with
  `0w` followed by a hexadecimal digit, such as `"0w12"`.
* **What goes wrong:** `0w` is taken for a prefix: `"0w12"` is read as the
  number `0wx12` and the whole string is consumed.
* **Required behaviour:** the
  [Basis `WORD` specification](https://smlfamily.github.io/Basis/word.html)
  gives the format of `StringCvt.HEX` as
  `(0wx | 0wX | 0x | 0X)?[0-9a-fA-F]+` (`0w` alone is a prefix of `BIN`,
  `OCT` and `DEC` only), and `scan` returns the number "parsed from a prefix
  of the character stream". The longest prefix of `"0w12"` in the format is
  `"0"`: `scan StringCvt.HEX` must give `SOME (0w0, "w12")`, and
  `fromString "0w12"` (which "is equivalent to
  `StringCvt.scanString (scan StringCvt.HEX)`") `SOME 0w0`.

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
(* In the HEX format of WORD.scan, (0wx | 0wX | 0x | 0X)?[0-9a-fA-F]+, "0w"
   alone is no prefix: "0w12" is the number 0 followed by "w12".  MLKit reads
   it as 0wx12. *)
fun rest (s, i) = String.extract (s, i, NONE)
fun reader s i = if i < String.size s then SOME (String.sub (s, i), i + 1) else NONE
fun scanned toString scan s =
  case scan StringCvt.HEX (reader s) 0 of
    NONE => "NONE"
  | SOME (w, i) => "SOME (0wx" ^ toString w ^ ", \"" ^ rest (s, i) ^ "\")"
fun opt toString NONE = "NONE"
  | opt toString (SOME w) = "SOME 0wx" ^ toString w
val s = "0w12"
val () = print ("Word.scan HEX \"0w12\"      = " ^ scanned Word.toString Word.scan s ^ "\n")
val () = print ("Word8.scan HEX \"0w12\"     = " ^ scanned Word8.toString Word8.scan s ^ "\n")
val () = print ("Word16.scan HEX \"0w12\"    = " ^ scanned Word16.toString Word16.scan s ^ "\n")
val () = print ("Word32.scan HEX \"0w12\"    = " ^ scanned Word32.toString Word32.scan s ^ "\n")
val () = print ("Word64.scan HEX \"0w12\"    = " ^ scanned Word64.toString Word64.scan s ^ "\n")
val () = print ("Word.fromString \"0w12\"    = " ^ opt Word.toString (Word.fromString s) ^ "\n")
val () = print ("Word8.fromString \"0w12\"   = " ^ opt Word8.toString (Word8.fromString s) ^ "\n")
val () = print ("Word32.fromString \"0w12\"  = " ^ opt Word32.toString (Word32.fromString s) ^ "\n")
val () = print ("Word64.fromString \"0w12\"  = " ^ opt Word64.toString (Word64.fromString s) ^ "\n")
(* for contrast: the valid prefixes, and 0wx without a digit after it *)
val () = print ("Word.scan HEX \"0wx12\"     = " ^ scanned Word.toString Word.scan "0wx12" ^ "\n")
val () = print ("Word.scan HEX \"0x12\"      = " ^ scanned Word.toString Word.scan "0x12" ^ "\n")
val () = print ("Word.fromString \"0wxg\"    = " ^ opt Word.toString (Word.fromString "0wxg") ^ "\n")
```

```
$ mlkit -o bug bug.mlb
[reading source file:	bug.sml]
[wrote X64 code file:	MLB/RI_GC/bug.sml.s]
[wrote X64 code file:	MLB/RI_GC/base-link_objects.s]
[wrote executable file:	bug]
$ ./bug
Word.scan HEX "0w12"      = SOME (0wx12, "")
Word8.scan HEX "0w12"     = SOME (0wx12, "")
Word16.scan HEX "0w12"    = SOME (0wx12, "")
Word32.scan HEX "0w12"    = SOME (0wx12, "")
Word64.scan HEX "0w12"    = SOME (0wx12, "")
Word.fromString "0w12"    = SOME 0wx12
Word8.fromString "0w12"   = SOME 0wx12
Word32.fromString "0w12"  = SOME 0wx12
Word64.fromString "0w12"  = SOME 0wx12
Word.scan HEX "0wx12"     = SOME (0wx12, "")
Word.scan HEX "0x12"      = SOME (0wx12, "")
Word.fromString "0wxg"    = SOME 0wx0
```

Every `"0w12"` line should read `SOME (0wx0, "w12")` or `SOME 0wx0`. The
last three lines are correct and are there for contrast. `Word31` and
`Word63`, which the program does not show, give `0wx12` for
`fromString "0w12"` as well.

## The cause

`scan` of `basis/Word.sml` (the one `Word16` uses too, through the `WordN`
functor) reads a `0`, then a `w` if there is one, and then, for `HEX`, an
`x` or `X` if there is one. When the `w` is not followed by an `x`, the
digits after it are read anyway:

```sml
	      fun hexprefix after0 src =
		  if radix <> HEX then getdigs after0 src
		  else
		      case getc src of
			  SOME(#"x", rest) => getdigs after0 rest
			| SOME(#"X", rest) => getdigs after0 rest
			| SOME _           => getdigs after0 src
			| NONE => SOME(fromInt 0, after0)
	  in
	      case getc source of
		  SOME(#"0", after0) =>
		      (case getc after0 of
			   SOME(#"w", src2) => hexprefix after0 src2
			 | SOME _           => hexprefix after0 after0
			 | NONE             => SOME(fromInt 0, after0))
```

For `"0w12"`, `hexprefix after0 src2` is called with `src2` at `"12"`; the
case `SOME _ => getdigs after0 src` then reads `12` from there. The
`SOME _` case is right when `hexprefix` was called after a `0` alone
(`"012"` is `0wx12`), but after `0w` the only valid continuation for `HEX`
is `x` or `X`. `Word8.sml`, `Word31.sml`, `Word32.sml`, `Word63.sml` and
`Word64.sml` each have their own copy of the same code.

## The fix

Tell `hexprefix` whether it follows `0w`, and after `0w` without `x` or `X`
return the `0` with the stream after it. For `basis/Word.sml`; `Word31.sml`,
`Word32.sml`, `Word63.sml` and `Word64.sml` take the same lines, and
`Word8.sml` the same change with `return 0w0 after0` for
`SOME(fromInt 0, after0)`:

```diff
--- a/basis/Word.sml
+++ b/basis/Word.sml
@@ -128,20 +128,20 @@
 		  case dig1 (getc src) of
 		      NONE => SOME(fromInt 0, after0)
 		    | res  => res
-	      fun hexprefix after0 src =
+	      fun hexprefix afterW after0 src =  (* afterW: src follows "0w" *)
 		  if radix <> HEX then getdigs after0 src
 		  else
 		      case getc src of
 			  SOME(#"x", rest) => getdigs after0 rest
 			| SOME(#"X", rest) => getdigs after0 rest
-			| SOME _           => getdigs after0 src
+			| SOME _           => if afterW then SOME(fromInt 0, after0) else getdigs after0 src
 			| NONE => SOME(fromInt 0, after0)
 	  in
 	      case getc source of
 		  SOME(#"0", after0) =>
 		      (case getc after0 of
-			   SOME(#"w", src2) => hexprefix after0 src2
-			 | SOME _           => hexprefix after0 after0
+			   SOME(#"w", src2) => hexprefix true after0 src2
+			 | SOME _           => hexprefix false after0 after0
 			 | NONE             => SOME(fromInt 0, after0))
 		| SOME _ => dig1 (getc source)
 		| NONE   => NONE
```

**Tested:** with this change applied to `Word.sml`, `Word8.sml`,
`Word32.sml` and `Word64.sml` of a copy of MLKit 4.7.23's library
(`SML_LIB` pointing at the copy), `bug.sml` prints `SOME (0wx0, "w12")`
and `SOME 0wx0` on every `"0w12"` line, and the Rune test programs `word`,
`word_scan`, `word8`, `intn_word16`, `intn_word32` and `intn_word64`
(below) pass all their checks. `Word31.sml` and `Word63.sml` were not
patched or tested. Not tried against a build of `master`.
The copy of the library had the fixes of the other reports of this
investigation applied as well (`Word.scan/0w-read-as-hex-prefix`,
`Word.fromLargeInt/Overflow-on-negative`, `IntInf.scan/*`,
`PackWord32Big.subVecX/no-sign-extension`, the `LargeIntVector` fix and
the runtime fix of `Int32.mod/SIGFPE-minInt-by-minus-one`); the Rune
programs were those the matrix compiled, `intn_word16` without its
`constants` section (`Int8.int/not-overloaded`).

## Relation to Rune

Rune's Basis Library suite (Rune at `3d83f11`) checks this with
`scan/HEX-0w-is-no-prefix` in `tests/basis/fn/word_scan_fn.sml` (line 115)
and `fromString/0w-is-no-prefix` in `tests/basis/fn/word_fn.sml`
(line 369). On MLKit they fail as `Word.scan/HEX-0w-is-no-prefix`
(`tests/basis/word_scan.sml`), `Word.fromString/0w-is-no-prefix`
(`word.sml`), `Word8.*` (`word8.sml`), and `Word16.*`, `Word32.*` and
`Word64.*` (`intn_word16.sml`, `intn_word32.sml`, `intn_word64.sml`).
Poly/ML has the same bug (`native:polyml@*` lines of
`tests/basis/deviations.txt`). The MLKit failures are explained by

```
native:mlkit@* | Word*.scan/HEX-0w-is-no-prefix | HOST-BUG | 0w is not a prefix of the hexadecimal format, but 0w12 is read as 0wx12
native:mlkit@* | Word*.fromString/0w-is-no-prefix | HOST-BUG | reads 0w12 as 0wx12, but 0w is not a prefix of the hexadecimal format
```
