# Draft: comment on smlnj/legacy#260

Where: https://github.com/smlnj/legacy/issues/260 (closed; a comment, or
ask for it to be reopened).

---

This is still present in 110.99.9 in the 32-bit builds, both the Linux
`config/install.sh -32` install and the Windows MSI.
`0wxFFFFFFFFFFFFFFFF : Word64.word` is `0wxFFFFFFFF3FFFFFFF`, and
`~5 : Int64.int` is `1073741819`. The commits for this issue (`ca65b54`,
`29585b3`) fixed the string-matching bug from the comment above, not the
literals.

The cause is how the 32-bit boot files are made. `Num64Cnv.split` computes
the low half as `IntInf.andb(n, 0xffffffff)`, and in the released 32-bit
compiler that `0xffffffff` is wrong:

* `transIntInf` (FLINT/trans/translate.sml) builds an `IntInf` literal from
  `LiteralToNum.repDigits`, which is `CoreIntInf.concrete` of the *host*.
* The x86 boot files are cross-compiled on amd64 (`allcross` in
  `admin/prepare-release.sh`), where the digits have 62 bits; the 32-bit
  target reads them as 30-bit digits.
* So `0xffffffff`, a single 62-bit digit, is not a valid 30-bit number, and
  `andb` with it keeps `n mod 2^30`.
* `0x10000000000000000`, which `split` adds to a negative constant, is
  `[0, 4]`, read as 2^32, so a negative constant loses its high half as
  well (`~5` becomes `2^32 - 5`).

Every `IntInf` literal of 2^30 or more in the 32-bit boot files is built
wrong this way. The 32-bit releases 110.98.1 to 110.99.7.1 and 110.99.9
have the bug; 110.99.8 does not, so its x86 boot files were presumably made
another way. That is why the problem goes away when the system is
compiled to a fixed point on a 32-bit machine (#373).

I checked this on Linux:
* boot files I cross-compiled on amd64 from the 110.99.9 sources
  (`cmb-cross -64 x86-unix`) give the release's wrong values;
* `fixpt -32` from the same sources does not;
* with the patch below, cross-compiled x86-unix and x86-win32 boot files
  (the latter installed on Windows with `config\install.bat`) give the right
  values.

The patch computes the digits for the target (30 or 62 bits after
`Target.is64`) and hands them over as `IntInf.int`, so that a 32-bit host
could cross-compile for a 64-bit target too. It does the same for `lowVal`,
which `genintinfswitch` uses to put small `IntInf` constants into a switch.
It is against legacy `main` (`6ed5a0a`) and also applies to 110.99.9:

```diff
diff --git a/base/compiler/FLINT/trans/literal-to-num.sml b/base/compiler/FLINT/trans/literal-to-num.sml
index 35d6334..f51d9b4 100644
--- a/base/compiler/FLINT/trans/literal-to-num.sml
+++ b/base/compiler/FLINT/trans/literal-to-num.sml
@@ -11,9 +11,15 @@ signature LITERAL_TO_NUM =
 
     val isNegative : IntInf.int -> bool
 
-    val repDigits : IntInf.int -> word list  (* expose representation *)
+  (* the digits of the magnitude of the number in the target's representation
+   * of intinf values, least significant first
+   *)
+    val repDigits : IntInf.int -> IntInf.int list
 
-    val lowVal : IntInf.int -> int option
+  (* the target's `CoreIntInf.lowValue` of the number, if it is not the
+   * `neg_base_as_int` that stands for a number of more than one digit
+   *)
+    val lowVal : IntInf.int -> IntInf.int option
 
   end
 
@@ -22,15 +28,22 @@ structure LiteralToNum : LITERAL_TO_NUM =
 
     fun isNegative (i : IntInf.int) = (i < 0)
 
-    local
-      fun unBI (CoreIntInf.BI x) = x
-    in
-    val repDigits = #digits o unBI o CoreIntInf.concrete
-    fun lowVal i = let
-	  val l = CoreIntInf.lowValue i
+  (* the digits must be those of the target's CoreIntInf, which has 62 bits per
+   * digit on 64-bit targets and 30 on 32-bit targets (see
+   * system/smlnj/init/target{64,32}-core-intinf.sml), not those of the host's,
+   * which differ when cross compiling
+   *)
+    val baseBits : word = if Target.is64 then 0w62 else 0w30
+    val base = IntInf.<< (1, baseBits)
+    val maxDigit = base - 1
+
+    fun repDigits i = let
+	  fun digits 0 = []
+	    | digits n = IntInf.andb (n, maxDigit) :: digits (IntInf.~>> (n, baseBits))
 	  in
-	    if l = CoreIntInf.neg_base_as_int then NONE else SOME l
+	    digits (IntInf.abs i)
 	  end
-    end (* local *)
+
+    fun lowVal i = if IntInf.abs i < base then SOME i else NONE
 
   end
diff --git a/base/compiler/FLINT/trans/translate-new.sml b/base/compiler/FLINT/trans/translate-new.sml
index e684735..29109d8 100644
--- a/base/compiler/FLINT/trans/translate-new.sml
+++ b/base/compiler/FLINT/trans/translate-new.sml
@@ -559,7 +559,7 @@ fun genintinfswitch (sv: LambdaVar.lvar, cases, default) =
 	      COND (APP (#getIntInfEq eqDict (), RECORD [VAR sv, VAR (getII n)]),
 		    e, build r)
 	(* make a small int constant pattern *)
-	fun mkSmall n = INTcon{ival = IntInf.fromInt n, ty = Tgt.defaultIntSz}
+	fun mkSmall n = INTcon{ival = n, ty = Tgt.defaultIntSz}
 	(* split pattern values into small values and large values;
 	 * small values can be handled directly using SWITCH *)
 	fun split ([], s, l) = (rev s, rev l)
@@ -1253,24 +1253,19 @@ and transIntInf d s =
      * could be subject to such things as constant folding. *)
     let val consexp = CONexp (BT.consDcon, [ref (TP.INSTANTIATED BT.wordTy)])
 	fun build [] = CONexp (BT.nilDcon, [ref (TP.INSTANTIATED BT.wordTy)])
-	  | build (d :: ds) = let
-	      val i = Word.toIntX d
-	      in
+	  | build (w :: ws) =
 		APPexp (consexp, EU.TUPLEexp [
-		    NUMexp("<lit>", {ival = IntInf.fromInt i, ty = BT.wordTy}),
-		    build ds
+		    NUMexp("<lit>", {ival = w, ty = BT.wordTy}),
+		    build ws
 		  ])
-	      end
 	fun mkSmallFn s = coreAcc(if LN.isNegative s then "makeSmallNegInf" else "makeSmallPosInf")
 	fun mkFn s = coreAcc(if LN.isNegative s then "makeNegInf" else "makePosInf")
 	fun small w =
 	      APP (mkSmallFn s,
-		mkExp (
-		  NUMexp("<lit>", {ival = IntInf.fromInt (Word.toIntX w), ty = BT.wordTy}),
-		  d))
+		mkExp (NUMexp("<lit>", {ival = w, ty = BT.wordTy}), d))
         in
 	  case LN.repDigits s
-           of [] => small 0w0
+           of [] => small 0
 	    | [w] => small w
 	    | ws => APP (mkFn s, mkExp (build ws, d))
         end
diff --git a/base/compiler/FLINT/trans/translate.sml b/base/compiler/FLINT/trans/translate.sml
index 353687c..536556d 100644
--- a/base/compiler/FLINT/trans/translate.sml
+++ b/base/compiler/FLINT/trans/translate.sml
@@ -504,7 +504,7 @@ fun genintinfswitch (sv, cases, default) =
 	      COND (APP (#getIntInfEq eqDict (), RECORD [VAR v, VAR (getII n)]),
 		    e, build r)
 	(* make a small int constant pattern *)
-	fun mkSmall n = INTcon{ival = IntInf.fromInt n, ty = Tgt.defaultIntSz}
+	fun mkSmall n = INTcon{ival = n, ty = Tgt.defaultIntSz}
 	(* split pattern values into small values and large values;
 	 * small values can be handled directly using SWITCH *)
 	fun split ([], s, l) = (rev s, rev l)
@@ -1107,24 +1107,19 @@ and transIntInf d s =
      * could be subject to such things as constant folding. *)
     let val consexp = CONexp (BT.consDcon, [ref (TP.INSTANTIATED BT.wordTy)])
 	fun build [] = CONexp (BT.nilDcon, [ref (TP.INSTANTIATED BT.wordTy)])
-	  | build (d :: ds) = let
-	      val i = Word.toIntX d
-	      in
+	  | build (w :: ws) =
 		APPexp (consexp, EU.TUPLEexp [
-		    NUMexp("<lit>", {ival = IntInf.fromInt i, ty = BT.wordTy}),
-		    build ds
+		    NUMexp("<lit>", {ival = w, ty = BT.wordTy}),
+		    build ws
 		  ])
-	      end
 	fun mkSmallFn s = coreAcc(if LN.isNegative s then "makeSmallNegInf" else "makeSmallPosInf")
 	fun mkFn s = coreAcc(if LN.isNegative s then "makeNegInf" else "makePosInf")
 	fun small w =
 	      APP (mkSmallFn s,
-		mkExp (
-		  NUMexp("<lit>", {ival = IntInf.fromInt (Word.toIntX w), ty = BT.wordTy}),
-		  d))
+		mkExp (NUMexp("<lit>", {ival = w, ty = BT.wordTy}), d))
         in
 	  case LN.repDigits s
-           of [] => small 0w0
+           of [] => small 0
 	    | [w] => small w
 	    | ws => APP (mkFn s, mkExp (build ws, d))
         end
```

Program (each constant beside the same number read from a string at run
time):

```sml
(* 64-bit literals on SML/NJ for 32 bits: bits 30 and 31 of the low half.
   Each line prints a Word64 or Int64 value written as a literal (or folded
   into one by the compiler) beside the same number made at run time from a
   string, and whether they are equal. Run: sml bug.sml *)
fun w64 s = valOf (StringCvt.scanString (Word64.scan StringCvt.HEX) s)
fun i64 s = valOf (Int64.fromString s)
fun showW (name, lit, s) =
      print (concat [name, " = ", Word64.fmt StringCvt.HEX lit, ", expected ",
                     Word64.fmt StringCvt.HEX (w64 s), ": ",
                     if lit = w64 s then "ok" else "WRONG", "\n"])
fun showI (name, lit, s) =
      print (concat [name, " = ", Int64.toString lit, ", expected ",
                     Int64.toString (i64 s), ": ",
                     if lit = i64 s then "ok" else "WRONG", "\n"])
val () = showW ("0wx40000000 : Word64.word", 0wx40000000, "40000000")
val () = showW ("0wx80000000 : Word64.word", 0wx80000000, "80000000")
val () = showW ("0wxFFFFFFFFFFFFFFFF : Word64.word", 0wxFFFFFFFFFFFFFFFF, "FFFFFFFFFFFFFFFF")
val () = showW ("Word64.fromInt 1073741823 + 0w1", Word64.fromInt 1073741823 + 0w1, "40000000")
val () = showI ("~5 : Int64.int", ~5, "~5")
val () = showI ("1073741824 : Int64.int", 1073741824, "1073741824")
val () = showI ("Int64.+ (~2, ~3)", Int64.+ (~2, ~3), "~5")
val () = OS.Process.exit OS.Process.success
```

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 32-bit; November 4, 2025]
0wx40000000 : Word64.word = 0, expected 40000000: WRONG
0wx80000000 : Word64.word = 0, expected 80000000: WRONG
0wxFFFFFFFFFFFFFFFF : Word64.word = FFFFFFFF3FFFFFFF, expected FFFFFFFFFFFFFFFF: WRONG
Word64.fromInt 1073741823 + 0w1 = 0, expected 40000000: WRONG
~5 : Int64.int = 1073741819, expected ~5: WRONG
1073741824 : Int64.int = 0, expected 1073741824: WRONG
Int64.+ (~2, ~3) = 1073741819, expected ~5: WRONG
```
