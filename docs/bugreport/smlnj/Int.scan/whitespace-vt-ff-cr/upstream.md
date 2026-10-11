# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Int.scan`, `Word.scan` and the other integer and word scanners do not skip `\v`, `\f` or `\r` (the rest of smlnj/smlnj#447)

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | Any |
| System Component | Basis Library |
| Severity | Minor |
| Also present in the "development" version? | Yes: `scan-util.sml` of smlnj/smlnj `17362d2` has the same table |

### Description

smlnj/smlnj#447 made `StringCvt.skipWS` skip vertical tabs, form feeds and
carriage returns, as `Char.isSpace` does; the fix is in legacy `main` too
(`87b5080`). The scanners of `Int`, `Int32`, `Int64`, `Word`, `Word8`,
`Word32` and `Word64` do not use `skipWS`: `ScanUtil.scanPrefix` skips the
characters whose code in `cvtTable` is 128, and only tab, newline and space
have it. So `Int.scan StringCvt.DEC Substring.getc (Substring.full "\r1")`
and `Word.fromString "\f1"` are still `NONE`, where the specification says
the number is parsed "after skipping initial whitespace". (`Int.fromString`
skips them: it has its own loop with `Char.isSpace`.) In practice, numbers
cannot be read from text with CRLF line ends:
`TextIO.scanStream (Int.scan StringCvt.DEC)` over `"1\r\n2\r\n"` gives
`SOME 1` and then `NONE`.

### Transcript

110.99.9, which does not have the fix of #447 either; with it, the first
four lines would be `ok`:

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
-- through StringCvt.skipWS (smlnj/smlnj#447, fixed after 110.99.9 and 2026.2)
StringCvt.skipWS: WRONG WRONG WRONG
Real.scan: WRONG WRONG WRONG
Bool.scan: WRONG WRONG WRONG
IntInf.scan: WRONG WRONG WRONG
-- through ScanUtil (not fixed)
Int.scan: WRONG WRONG WRONG
Int32.scan: WRONG WRONG WRONG
Int64.scan: WRONG WRONG WRONG
Word.scan: WRONG WRONG WRONG
Word8.scan: WRONG WRONG WRONG
Word32.scan: WRONG WRONG WRONG
Word64.scan: WRONG WRONG WRONG
Int64.fromString: WRONG WRONG WRONG
Word.fromString: WRONG WRONG WRONG
```

### Expected Behavior

`ok` throughout: each scanner skips the three characters, as MLton, Poly/ML
and MLKit do.

### Steps to Reproduce

```sml
(* Scanning after a vertical tab, a form feed or a carriage return, which
   Char.isSpace counts as white space. StringCvt.skipWS "strips whitespace
   characters ... A whitespace character is one that satisfies the predicate
   Char.isSpace", and the scanners skip "initial whitespace". Each line reads
   "<c>1" (or "<c>true") for c = \v, \f and \r. Run: sml bug.sml *)
fun line (name, ok) =
      let val r = map (fn c => ok (String.str c) handle _ => false) [#"\v", #"\f", #"\r"]
      in print (concat [name, ": ", String.concatWith " " (map (fn true => "ok" | false => "WRONG") r), "\n"])
      end
fun scanned scan s = (case scan Substring.getc (Substring.full s)
       of SOME (_, rest) => Substring.isEmpty rest
        | NONE => false)
val () = print "-- through StringCvt.skipWS (smlnj/smlnj#447, fixed after 110.99.9 and 2026.2)\n"
val () = line ("StringCvt.skipWS", fn c => Substring.string (StringCvt.skipWS Substring.getc (Substring.full (c ^ "1"))) = "1")
val () = line ("Real.scan", fn c => scanned Real.scan (c ^ "1"))
val () = line ("Bool.scan", fn c => scanned Bool.scan (c ^ "true"))
val () = line ("IntInf.scan", fn c => scanned (IntInf.scan StringCvt.DEC) (c ^ "1"))
val () = print "-- through ScanUtil (not fixed)\n"
val () = line ("Int.scan", fn c => scanned (Int.scan StringCvt.DEC) (c ^ "1"))
val () = line ("Int32.scan", fn c => scanned (Int32.scan StringCvt.DEC) (c ^ "1"))
val () = line ("Int64.scan", fn c => scanned (Int64.scan StringCvt.DEC) (c ^ "1"))
val () = line ("Word.scan", fn c => scanned (Word.scan StringCvt.HEX) (c ^ "1"))
val () = line ("Word8.scan", fn c => scanned (Word8.scan StringCvt.HEX) (c ^ "1"))
val () = line ("Word32.scan", fn c => scanned (Word32.scan StringCvt.HEX) (c ^ "1"))
val () = line ("Word64.scan", fn c => scanned (Word64.scan StringCvt.HEX) (c ^ "1"))
val () = line ("Int64.fromString", fn c => Int64.fromString (c ^ "1") = SOME 1)
val () = line ("Word.fromString", fn c => Word.fromString (c ^ "1") = SOME 0w1)
val () = OS.Process.exit OS.Process.success
```

### Additional Information

The patch gives codes 11, 12 and 13 the white-space code 128 in `cvtTable`.
That code is only compared with `wsCode` in `scanPrefix`; everywhere else
a code is compared with digit values or the codes of `+`, `-`, `.`, `e`,
`w` and `x`, so 128 stops a number as 255 did. It is against legacy `main`
(`6ed5a0a`) and also applies to 110.99.9 and, with `-p2`, to smlnj/smlnj:

```diff
diff --git a/base/system/Basis/Implementation/scan-util.sml b/base/system/Basis/Implementation/scan-util.sml
index 5e34344..a24b616 100644
--- a/base/system/Basis/Implementation/scan-util.sml
+++ b/base/system/Basis/Implementation/scan-util.sml
@@ -54,13 +54,14 @@ structure ScanUtil : sig
 
   end = struct
 
-  (* A table for mapping digits to values.  Whitespace characters map to
-   * 128, "+" maps to 129, "-","~" map to 130, "." maps to 131, and the
-   * characters 0-9,A-Z,a-z map to their base-36 value.  All other
+  (* A table for mapping digits to values.  Whitespace characters (those of
+   * Char.isSpace: space, tab, newline, vertical tab, form feed and carriage
+   * return) map to 128, "+" maps to 129, "-","~" map to 130, "." maps to 131,
+   * and the characters 0-9,A-Z,a-z map to their base-36 value.  All other
    * characters map to 255.
    *)
     val cvtTable = "\
-	  \\255\255\255\255\255\255\255\255\255\128\128\255\255\255\255\255\
+	  \\255\255\255\255\255\255\255\255\255\128\128\128\128\128\255\255\
 	  \\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
 	  \\128\255\255\255\255\255\255\255\255\255\255\129\255\130\131\255\
 	  \\000\001\002\003\004\005\006\007\008\009\255\255\255\255\255\255\
```

Not built: a copy of the table before and after the patch shows that after
it a character has the code 128 exactly when `Char.isSpace` holds of it,
and that no other entry changed.
