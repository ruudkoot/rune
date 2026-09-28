# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Int64.toInt`, `Position.toInt` and `Word64.toIntX` ignore the high word on 32-bit systems

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Linux, Windows |
| OS Version | Ubuntu 24.04 (WSL2); Windows 11 (10.0.22000) |
| Processor | x86 (32-bit) |
| System Component | Core system |
| Severity | Major |
| Also present in the "development" version? | No (it has no 32-bit target) |

### Description

In the 32-bit build, a signed conversion from 64 bits to `int` (`Int64.toInt`,
`Position.toInt`, `Word64.toIntX`) does not raise `Overflow` for a number
that does not fit. It takes the low 32 bits as a 32-bit integer and checks
only that against 31 bits. `Int64.toInt 4294967296` is `0`, so a file
position of 4 GiB becomes 0. This happens in the Linux release, the Windows
MSI, and a native `fixpt -32` build.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 32-bit; November 4, 2025]
Int64.toInt 4294967296 = 0, expected Overflow: WRONG
Int64.toInt 3221225472 = ~1073741824, expected Overflow: WRONG
Int64.toInt ~4294967297 = ~1, expected Overflow: WRONG
Int64.toInt ~5 = ~5, expected ~5: ok
Word64.toIntX 0wx100000000 = 0, expected Overflow: WRONG
Word64.toIntX 0wxFFFFFFFF = ~1, expected Overflow: WRONG
Word64.toIntX 0wxFFFFFFFFFFFFFFFB = ~5, expected ~5: ok
Position.toInt 4294967296 = 0, expected Overflow: WRONG
```

### Expected Behavior

`Overflow` for each number that does not fit 31 bits (the program's
expectations follow the width of `int`, and the 64-bit build prints `ok`
throughout).

### Steps to Reproduce

```sml
(* Int64.toInt, Word64.toIntX and Position.toInt: a number that does not fit
   int must raise Overflow (on SML/NJ for 32 bits, int has 31 bits). The
   numbers are read from strings at run time. Run: sml bug.sml *)
fun i s = valOf (Int64.fromString s)
fun w s = valOf (StringCvt.scanString (Word64.scan StringCvt.HEX) s)
fun fits v = case (Int.minInt, Int.maxInt) of
                 (SOME lo, SOME hi) => Int.toLarge lo <= v andalso v <= Int.toLarge hi
               | _ => true
fun show (name, f, value) =
      let val v = valOf (IntInf.fromString value)
          val expected = if fits v then IntInf.toString v else "Overflow"
          val got = (Int.toString (f ())) handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
val () = show ("Int64.toInt 4294967296", fn () => Int64.toInt (i "4294967296"), "4294967296")
val () = show ("Int64.toInt 3221225472", fn () => Int64.toInt (i "3221225472"), "3221225472")
val () = show ("Int64.toInt ~4294967297", fn () => Int64.toInt (i "~4294967297"), "~4294967297")
val () = show ("Int64.toInt ~5", fn () => Int64.toInt (i "~5"), "~5")
val () = show ("Word64.toIntX 0wx100000000", fn () => Word64.toIntX (w "100000000"), "4294967296")
val () = show ("Word64.toIntX 0wxFFFFFFFF", fn () => Word64.toIntX (w "FFFFFFFF"), "4294967295")
val () = show ("Word64.toIntX 0wxFFFFFFFFFFFFFFFB", fn () => Word64.toIntX (w "FFFFFFFFFFFFFFFB"), "~5")
val () = show ("Position.toInt 4294967296", fn () => Position.toInt (valOf (Position.fromString "4294967296")), "4294967296")
val () = OS.Process.exit OS.Process.success
```

### Additional Information

For `PO.TEST(64, to)` on 32-bit targets, `chkPrim` (FLINT/trans/transprim.sml)
passes `coreAcc "w64ToInt32X"` as the conversion function. That is
`CoreWord64.toInt32X = copy_word32_to_int32 (#2 (extern w))`, which does not
look at the high word. The checked conversion exists as `i64ToInt32`
(`CoreInt64.toInt32`) and is not used. The patch passes `i64ToInt32`. It is
against legacy `main` (`6ed5a0a`) and also applies to 110.99.9:

```diff
diff --git a/base/compiler/FLINT/trans/transprim.sml b/base/compiler/FLINT/trans/transprim.sml
index fd02ce3..e165e71 100644
--- a/base/compiler/FLINT/trans/transprim.sml
+++ b/base/compiler/FLINT/trans/transprim.sml
@@ -307,7 +307,7 @@ structure TransPrim : sig
 			in
 			  mkFn argTy (fn arg =>
 			    L.APP(L.PRIM(po, primTy, []),
-			      L.RECORD[arg, coreAcc "w64ToInt32X"]))
+			      L.RECORD[arg, coreAcc "i64ToInt32"]))
 			end
 		    | chkPrim arg = L.PRIM arg
 		  in
```

Tested with a fixed point for 32 bits and with cross-compiled x86-unix and
x86-win32 boot files. A check of every conversion between `int`, `Int32`,
`Int64`, `word`, `Word8`, `Word32` and `Word64` on 31 numbers, against
results computed with `IntInf`, has no wrong result with this patch and
those filed alongside it (fused conversions, 64-bit literals).
