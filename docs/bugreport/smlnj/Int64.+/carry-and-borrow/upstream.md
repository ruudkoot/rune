# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Int64.+` and `Int64.-` give wrong results on 32-bit systems

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

In the 32-bit build, `Int64.+` gives a wrong result whenever the low halves
carry into the high half, and `Int64.-` whenever its second operand has a
nonzero high half (it is negative, or 2^32 or more). `Position.int` is
`Int64.int` there, so file positions are affected as well. Overflow is
missed too. This happens in the Linux release (`config/install.sh -32`), the
Windows MSI, and a native `fixpt -32` build; the 64-bit build is right.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 32-bit; November 4, 2025]
~2 + ~3 = ~8589934597, expected ~5: WRONG
~1 + 1 = ~8589934592, expected 0: WRONG
4294967295 + 1 = ~4294967296, expected 4294967296: WRONG
9223372036854775807 + 1 = 9223372028264841216, expected Overflow: WRONG
5 - ~3 = ~8589934584, expected 8: WRONG
0 - 4294967296 = 4294967296, expected ~4294967296: WRONG
~9223372036854775808 - 1 = Overflow, expected Overflow: ok
```

### Expected Behavior

The sum or difference, or `Overflow` when it does not fit 64 bits:

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
~2 + ~3 = ~5, expected ~5: ok
~1 + 1 = 0, expected 0: ok
4294967295 + 1 = 4294967296, expected 4294967296: ok
9223372036854775807 + 1 = Overflow, expected Overflow: ok
5 - ~3 = 8, expected 8: ok
0 - 4294967296 = ~4294967296, expected ~4294967296: ok
~9223372036854775808 - 1 = Overflow, expected Overflow: ok
```

### Steps to Reproduce

The operands are read from strings, so that nothing is folded at compile
time:

```sml
(* Int64 + and - on SML/NJ for 32 bits, on numbers the compiler cannot see:
   they are read from strings at run time. Run: sml bug.sml *)
fun i s = valOf (Int64.fromString s)
fun show (name, f, a, b, expected) =
      let val got = (Int64.toString (f (i a, i b))) handle Overflow => "Overflow"
      in print (concat [a, " ", name, " ", b, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
val () = show ("+", Int64.+, "~2", "~3", "~5")
val () = show ("+", Int64.+, "~1", "1", "0")
val () = show ("+", Int64.+, "4294967295", "1", "4294967296")
val () = show ("+", Int64.+, "9223372036854775807", "1", "Overflow")
val () = show ("-", Int64.-, "5", "~3", "8")
val () = show ("-", Int64.-, "0", "4294967296", "~4294967296")
val () = show ("-", Int64.-, "~9223372036854775808", "1", "Overflow")
val () = OS.Process.exit OS.Process.success
```

### Additional Information

`Num64Cnv.i64Add` (CPS/opt/num64cnv.sml) computes the carry with
`P.RSHIFT`, an arithmetic shift, so it is 0 or -1 rather than 0 or 1 (the
comment has `>> 0w31`, and `w64Add` uses `P.RSHIFTL`). The high half comes
out as `hi1 + hi2 - 1` where it should be `hi1 + hi2 + 1`.

`i64Sub` has the same shift for the borrow, and adds where its comment
subtracts: it computes `hi1 + hi2 - b` for `hi1 - hi2 - b`.

The patch shifts logically and uses `ISUB`, in the order of the comment's
algorithm, which keeps `Overflow` right in the edge cases. It is against
legacy `main` (`6ed5a0a`) and also applies to 110.99.9:

```diff
diff --git a/base/compiler/CPS/opt/num64cnv.sml b/base/compiler/CPS/opt/num64cnv.sml
index acb8f80..e9b0ec8 100644
--- a/base/compiler/CPS/opt/num64cnv.sml
+++ b/base/compiler/CPS/opt/num64cnv.sml
@@ -425,7 +425,7 @@ structure Num64Cnv : sig
 	      pure_arith32(P.ANDB, [lo1_or_lo2, not_lo], fn tmp1 =>
 	      pure_arith32(P.ANDB, [lo1, lo2], fn lo1_and_lo2 =>
 	      pure_arith32(P.ORB, [lo1_and_lo2, tmp1], fn tmp2 =>
-	      pure_arith32(P.RSHIFT, [tmp2, tagNum 31], fn carry =>
+	      pure_arith32(P.RSHIFTL, [tmp2, tagNum 31], fn carry =>
 	      join (hi,
 		to64(C.VAR hi, lo, k),
 		fn k' =>
@@ -462,16 +462,16 @@ structure Num64Cnv : sig
 	      pure_arith32(P.NOTB, [lo1], fn not_lo1 =>
 	      pure_arith32(P.ANDB, [not_lo1, lo2], fn tmp2 =>
 	      pure_arith32(P.ORB, [tmp1, tmp2], fn tmp3 =>
-	      pure_arith32(P.RSHIFT, [tmp3, tagNum 31], fn borrow =>
+	      pure_arith32(P.RSHIFTL, [tmp3, tagNum 31], fn borrow =>
 	      join (hi,
 		to64(C.VAR hi, lo, k),
 		fn k' =>
 		  sIf(P.LTE, hi1, hi2,
-		    iarith32(P.IADD, [hi1, hi2], fn tmp1 =>
-		    iarith32(P.IADD, [tmp1, borrow], k')),
+		    iarith32(P.ISUB, [hi1, hi2], fn tmp1 =>
+		    iarith32(P.ISUB, [tmp1, borrow], k')),
 		    (* else *)
-		    iarith32(P.IADD, [hi1, borrow], fn tmp2 =>
-		    iarith32(P.IADD, [tmp2, hi2], k'))))))))))))))
+		    iarith32(P.ISUB, [hi1, borrow], fn tmp2 =>
+		    iarith32(P.ISUB, [tmp2, hi2], k'))))))))))))))
 	  end
 
   (*
```

Tested with a fixed point for 32 bits and with cross-compiled x86-unix and
x86-win32 boot files. `+`, `-`, `*`, `div`, `mod`, `quot`, `rem` and the
comparisons of `Int64` then agree with the 64-bit build on all 576 pairs of
24 operands, apart from `mod`/`rem (minInt, ~1)`, where the 32-bit build
gives the right answer 0 and the 64-bit build raises an exception.
