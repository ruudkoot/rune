# Draft: comment on smlnj/legacy#373

Where: https://github.com/smlnj/legacy/issues/373 (open).

---

The one-ulp error has a second cause besides the literal lowering in the
trace above, and a fixed point on a 32-bit machine does not remove it. On a
native `fixpt -32` build of the 110.99.9 sources (Linux), none of the 18
values listed in this issue round-trip, and neither do 1,799 of 20,000
`Random.randReal` values.

The cause is `Num64Cnv`'s lowering of 64-bit shifts on 32-bit targets:

* **A shift by 0** computes `hi << (32 - 0)` and `lo >> 32`, which x86
  takes mod 32. So `0wx1 << 0w0` is `0wx100000001`, and
  `0wx100000000 >> 0w0` is `0wx100000001`.
* **`w64RShift` swaps its shifts:** it shifts the low half arithmetically
  for amounts below 32, and the high half logically for 32 and above. Its
  comment has them the other way round. So `0wx80000000 ~>> 0w1` is
  `0wxC0000000`.
* **`~>>` by 64 or more:** `inlineArithmeticShiftRight`
  (FLINT/trans/transprim.sml) replaces such an amount with
  `Tgt.defaultIntSz`, which is 31 there, not 63.
* **Negation:** `Word64.~ 0wx8000000000000000` raises `Overflow`, because
  `UINT 64` `NEG` is dispatched to `i64Neg` instead of `w64Neg`, which is
  never used.

`frep-to-real64.sml` rounds with `Word64` shifts by amounts computed from
the exponents, e.g. `W64.lshift(0w1, p) - 0w1` in `multipleOfPowerOf2`, so a
wrong shift by 0 changes the rounding. With only the patch below, built to a
fixed point:
* all the values in this issue round-trip;
* so do 20,000 random ones;
* `Real.fromString "1.5e~2"` is `0.015` (it is not in the 32-bit
  release).

`Word64` shifts and arithmetic then agree with the 64-bit build on 24
operands and shift amounts 0, 1, 29-33, 63 and 64.

The literal lowering in the trace above is #260; I have commented on its
cause there.

The patch, against legacy `main` (`6ed5a0a`); it also applies to 110.99.9:

```diff
diff --git a/base/compiler/CPS/opt/num64cnv.sml b/base/compiler/CPS/opt/num64cnv.sml
index acb8f80..b6c7c3e 100644
--- a/base/compiler/CPS/opt/num64cnv.sml
+++ b/base/compiler/CPS/opt/num64cnv.sml
@@ -264,7 +264,8 @@ structure Num64Cnv : sig
   (* logical shift-right, where we know that amt < 0w64
    *
    * fun w63RShiftL ((hi, lo), amt) =
-   *	   if (amt < 32)
+   *	   if (amt = 0) then (hi, lo)
+   *	   else if (amt < 32)
    *	     then let
    *	       val hi' = (hi >> amt)
    *           val lo' = (lo >> amt) | (hi << (0w32 - amt))
@@ -274,9 +275,11 @@ structure Num64Cnv : sig
    *         else (0, (hi >> (amt - 0w32)))
    *
    * Note, that while there is a branch-free version of this, it does not work
-   * on the x86 architecture, which uses mod-32 shift amounts.
+   * on the x86 architecture, which uses mod-32 shift amounts; for the same reason,
+   * a shift by 0 needs its own case, since `0w32 - amt` would be 0w32.
    *)
     fun w64RShiftL (n, amt, res, cexp) = join (res, cexp, fn k =>
+	  sIf(P.EQL, amt, tagNum 0, k n,
 	  from64(n, fn (hi, lo) =>
 	    sIf(P.LT, amt, tagNum 32,
 	      pure_arith32(P.RSHIFTL, [hi, amt], fn hi' =>
@@ -288,12 +291,13 @@ structure Num64Cnv : sig
 	      (* else *)
 	      taggedArith(P.SUB, [amt, tagNum 32], fn tmp4 =>
 	      pure_arith32(P.RSHIFTL, [hi, tmp4], fn lo' =>
-		to64(zero, lo', k))))))
+		to64(zero, lo', k)))))))
 
   (*arithmetic shift-right, where we know that amt < 0w64
    *
    * fun w63RShift ((hi, lo), amt) =
-   *	   if (amt < 32)
+   *	   if (amt = 0) then (hi, lo)
+   *	   else if (amt < 32)
    *	     then let
    *	       val hi' = (hi ~>> amt)
    *           val lo' = (lo >> amt) | (hi << (0w32 - amt))
@@ -306,10 +310,11 @@ structure Num64Cnv : sig
    * on the x86 architecture, which uses mod-32 shift amounts.
    *)
     fun w64RShift (n, amt, res, cexp) = join (res, cexp, fn k =>
+	  sIf(P.EQL, amt, tagNum 0, k n,
 	  from64(n, fn (hi, lo) =>
 	    sIf(P.LT, amt, tagNum 32,
 	      pure_arith32(P.RSHIFT, [hi, amt], fn hi' =>
-	      pure_arith32(P.RSHIFT, [lo, amt], fn tmp1 =>
+	      pure_arith32(P.RSHIFTL, [lo, amt], fn tmp1 =>
 	      taggedArith(P.SUB, [tagNum 32, amt], fn tmp2 =>
 	      pure_arith32(P.LSHIFT, [hi, tmp2], fn tmp3 =>
 	      pure_arith32(P.ORB, [tmp1, tmp3], fn lo' =>
@@ -317,13 +322,14 @@ structure Num64Cnv : sig
 	      (* else *)
 	      pure_arith32(P.RSHIFT, [hi, tagNum 31], fn hi' =>
 	      taggedArith(P.SUB, [amt, tagNum 32], fn tmp4 =>
-	      pure_arith32(P.RSHIFTL, [hi, tmp4], fn lo' =>
-		to64(hi', lo', k)))))))
+	      pure_arith32(P.RSHIFT, [hi, tmp4], fn lo' =>
+		to64(hi', lo', k))))))))
 
   (* shift-left, where we know that amt < 0w64
    *
    * fun w64LShift ((hi, lo), amt) =
-   *	   if (amt < 0w32)
+   *	   if (amt = 0w0) then (hi, lo)
+   *	   else if (amt < 0w32)
    *	     then let
    *	       val hi' = (hi << amt) | (lo >> (0w32 - amt))
    *           val lo' = (lo << amt)
@@ -336,6 +342,7 @@ structure Num64Cnv : sig
    * on the x86 architecture, which uses mod-32 shift amounts.
    *)
     fun w64LShift (n, amt, res, cexp) = join (res, cexp, fn k =>
+	  sIf(P.EQL, amt, tagNum 0, k n,
 	  from64(n, fn (hi, lo) =>
 	    sIf(P.LT, amt, tagNum 32,
 	      pure_arith32(P.LSHIFT, [hi, amt], fn tmp1 =>
@@ -347,7 +354,7 @@ structure Num64Cnv : sig
 	      (* else *)
 	      taggedArith(P.SUB, [amt, tagNum 32], fn tmp4 =>
 	      pure_arith32(P.LSHIFT, [lo, tmp4], fn hi' =>
-		to64(hi', zero, k))))))
+		to64(hi', zero, k)))))))
 
   (*
    * fun w64Eql ((hi1, lo1), (hi2, lo2)) =
@@ -723,7 +730,7 @@ structure Num64Cnv : sig
 		    | (P.MUL, [a, b, f]) => mkApply(f, [a, b], res, e)
 		    | (P.QUOT, [a, b, f]) => mkApply(f, [a, b], res, e)
 		    | (P.REM , [a, b, f]) => mkApply(f, [a, b], res, e)
-		    | (P.NEG, [a]) => i64Neg(a, res, cexp e)
+		    | (P.NEG, [a]) => w64Neg(a, res, cexp e)
 		    | (P.ORB, [a, b]) => w64Orb(a, b, res, cexp e)
 		    | (P.XORB, [a, b]) => w64Xorb(a, b, res, cexp e)
 		    | (P.ANDB, [a, b]) => w64Andb(a, b, res, cexp e)
diff --git a/base/compiler/FLINT/trans/transprim.sml b/base/compiler/FLINT/trans/transprim.sml
index fd02ce3..dd452ef 100644
--- a/base/compiler/FLINT/trans/transprim.sml
+++ b/base/compiler/FLINT/trans/transprim.sml
@@ -341,7 +341,7 @@ structure TransPrim : sig
 	  fun inlineArithmeticShiftRight (kind as PO.UINT sz) = let
 		fun lword n = L.WORD{ival = Int.toLarge n, ty = Tgt.defaultIntSz}
 		val shiftLimit = lword sz
-		val shiftWidth = lword Tgt.defaultIntSz
+		val shiftWidth = lword (if sz > Tgt.defaultIntSz then sz - 1 else Tgt.defaultIntSz)
 		val argt = lt_tup [baselt kind, lt_int]
 		val cmpShiftAmt =
 		      L.PRIM(PO.CMP{oper=PO.LTE, kind=PO.UINT Tgt.defaultIntSz}, lt_icmp, [])
```

Program:

```sml
(* Word64 shifts and negation on SML/NJ for 32 bits. Every operand is read
   from a string at run time, so that nothing is folded; the expected values
   are those of the 64-bit build, MLton and Poly/ML. Run: sml bug.sml *)
fun w s = valOf (StringCvt.scanString (Word64.scan StringCvt.HEX) s)
fun show (name, f, expected) =
      let val got = (Word64.fmt StringCvt.HEX (f ())) handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
val n = Word.fromInt o valOf o Int.fromString
val () = show ("0wx1 << 0w0", fn () => Word64.<< (w "1", n "0"), "1")
val () = show ("0wx100000000 >> 0w0", fn () => Word64.>> (w "100000000", n "0"), "100000000")
val () = show ("0wx100000000 ~>> 0w0", fn () => Word64.~>> (w "100000000", n "0"), "100000000")
val () = show ("0wx80000000 ~>> 0w1", fn () => Word64.~>> (w "80000000", n "1"), "40000000")
val () = show ("0wx8000000000000000 ~>> 0w33", fn () => Word64.~>> (w "8000000000000000", n "33"), "FFFFFFFFC0000000")
val () = show ("0wx80000000 ~>> 0w64", fn () => Word64.~>> (w "80000000", n "64"), "0")
val () = show ("0wx8000000000000000 ~>> 0w64", fn () => Word64.~>> (w "8000000000000000", n "64"), "FFFFFFFFFFFFFFFF")
val () = show ("Word64.~ 0wx8000000000000000", fn () => Word64.~ (w "8000000000000000"), "8000000000000000")
val () = OS.Process.exit OS.Process.success
```

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 32-bit; November 4, 2025]
0wx1 << 0w0 = 100000001, expected 1: WRONG
0wx100000000 >> 0w0 = 100000001, expected 100000000: WRONG
0wx100000000 ~>> 0w0 = 100000001, expected 100000000: WRONG
0wx80000000 ~>> 0w1 = C0000000, expected 40000000: WRONG
0wx8000000000000000 ~>> 0w33 = FFFFFFFF40000000, expected FFFFFFFFC0000000: WRONG
0wx80000000 ~>> 0w64 = FFFFFFFF, expected 0: WRONG
0wx8000000000000000 ~>> 0w64 = FFFFFFFF00000000, expected FFFFFFFFFFFFFFFF: WRONG
Word64.~ 0wx8000000000000000 = Overflow, expected 8000000000000000: WRONG
```
