# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Real.ceil`, `trunc` and `round` are off by one, and on 64-bit systems `Real.floor` and friends wrap around instead of raising `Overflow`

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2); Windows 11 (10.0.22000) |
| Processor | x86 (32-bit), x86-64 (64-bit) |
| System Component | Basis Library |
| Severity | Major |
| Also present in the "development" version? | Yes: `pervasive.sml` and `target64-inline.sml` of smlnj/smlnj `a5f3fa7` have the same code (read, not run) |

### Description

* **All targets, `ceil` just above an integer.** `Real.ceil` is one too
  small there: `ceil (nextAfter (3.0, 4.0))` is 3, and `ceil 1.0E~20` and
  `ceil minPos` are 0. `trunc` of a negative number, which is `ceil`, is off
  the same way.
* **64-bit, near 2^62.** `Real.floor` (and so `ceil`, `trunc` and `round`)
  of a number from 2^62 to 2^62 + 2048, or from -(2^62 + 2048) to just below
  -2^62, wraps around instead of raising `Overflow`. `floor (2^62)` and
  `round (2^62)` are `minInt`, and `trunc (~(2^62))` is `maxInt`.
* **64-bit, above 2^52.** `round (2^52 + 1.0)` is 2^52 + 2.
* **32-bit, just below `minInt`.** `round (real minInt - 0.5)` raises
  `Overflow`, although the tie goes to the even `minInt`.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
ceil minPos = 0, expected 1: WRONG
ceil (nextAfter (3.0, 4.0)) = 3, expected 4: WRONG
ceil 1.0E~20 = 0, expected 1: WRONG
trunc (~(2^62) + 512.0) = ~4611686018427387393, expected ~4611686018427387392: WRONG
floor (2^62) = ~4611686018427387904, expected Overflow: WRONG
floor (~(2^62) - 2048.0) = 4611686018427385856, expected Overflow: WRONG
trunc (~(2^62)) = 4611686018427387903, expected ~4611686018427387904: WRONG
round (2^62) = ~4611686018427387904, expected Overflow: WRONG
round (real minInt - 0.5) = ~4611686018427387904, expected ~4611686018427387904: ok
round (2^52 + 1.0) = 4503599627370498, expected 4503599627370497: WRONG
round 2.5 = 2, expected 2: ok
round ~2.5 = ~2, expected ~2: ok
```

On 32 bits the three `ceil` lines and `round (real minInt - 0.5)` are
wrong.

### Expected Behavior

The exact integer, or `Overflow` when it does not fit `int`: the expected
value of each line. MLton and Poly/ML print `ok` throughout.

### Steps to Reproduce

```sml
(* Real.floor, ceil, trunc and round near integers and at the ends of int.
   Each expected value is the exact mathematical result, or Overflow when that
   does not fit int (31 bits on SML/NJ for 32 bits, 63 for 64); the reals are
   made exactly. Run: sml bug.sml *)
fun p2 n = Real.fromManExp {man = 1.0, exp = n}
fun big s = valOf (IntInf.fromString s)
fun fits v = case (Int.minInt, Int.maxInt) of
               (SOME lo, SOME hi) => Int.toLarge lo <= v andalso v <= Int.toLarge hi
             | _ => true
fun show (name, f, value) =
      let val expected = if fits (big value) then value else "Overflow"
          val got = (IntInf.toString (Int.toLarge (f ()))) handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
val minInt = real (valOf Int.minInt)
val () = show ("ceil minPos", fn () => Real.ceil Real.minPos, "1")
val () = show ("ceil (nextAfter (3.0, 4.0))", fn () => Real.ceil (Real.nextAfter (3.0, 4.0)), "4")
val () = show ("ceil 1.0E~20", fn () => Real.ceil 1.0E~20, "1")
val () = show ("trunc (~(2^62) + 512.0)", fn () => Real.trunc (~(p2 62) + 512.0), "~4611686018427387392")
val () = show ("floor (2^62)", fn () => Real.floor (p2 62), "4611686018427387904")
val () = show ("floor (~(2^62) - 2048.0)", fn () => Real.floor (~(p2 62) - 2048.0), "~4611686018427389952")
val () = show ("trunc (~(2^62))", fn () => Real.trunc (~(p2 62)), "~4611686018427387904")
val () = show ("round (2^62)", fn () => Real.round (p2 62), "4611686018427387904")
val () = show ("round (real minInt - 0.5)", fn () => Real.round (minInt - 0.5), IntInf.toString (Int.toLarge (valOf Int.minInt)))
val () = show ("round (2^52 + 1.0)", fn () => Real.round (p2 52 + 1.0), "4503599627370497")
val () = show ("round 2.5", fn () => Real.round 2.5, "2")
val () = show ("round ~2.5", fn () => Real.round ~2.5, "~2")
val () = OS.Process.exit OS.Process.success
```

### Additional Information

* **64-bit `floor`.** `target64-inline.sml` bounds it with
  `rminInt = ~4611686018427390000.0` and
  `rmaxInt = 4611686018427390000.0`, which are ±(2^62 + 2048) as reals,
  and tests `x <= rmaxInt`. Everything in between reaches
  `Assembly.A.floor`, whose tagging shift then overflows. The 32-bit
  version tests `-2^30 <= x < 2^30` exactly.
* **`ceil`** (`pervasive.sml`) is `~1 - floor (~(x + 1.0))`, which is
  wrong whenever `x + 1.0` rounds: for `x` less than half an ulp of n + 1
  above an integer n, and above 2^53.
* **`round`** uses `floor (x + 0.5)` and `ceil (x - 0.5)`, with the same
  problem above 2^52. `ceil (x - 0.5)` is also out of range for
  `x = real minInt - 0.5`.

The patch bounds the 64-bit `floor` exactly, and builds `ceil` and `round`
on `floor x` and the exact difference `x - real (floor x)`. Where `floor x`
is out of range but the result is `minInt`, the handler uses `x + 1.0` or
`x + 0.5`, which are exact there. It is against legacy `main` (`6ed5a0a`)
and also applies to 110.99.9:

```diff
diff --git a/base/system/smlnj/init/pervasive.sml b/base/system/smlnj/init/pervasive.sml
index 4024c82..141a4e6 100644
--- a/base/system/smlnj/init/pervasive.sml
+++ b/base/system/smlnj/init/pervasive.sml
@@ -171,19 +171,32 @@ val real = R64.from_int
 
 val floor = R64.floor
 
-fun ceil x = Int.- (~1, floor (R64.~ (x + 1.0)))
+(* ceil and round start from floor x, which checks the range of int, and from
+ * the difference between x and it, which is exact.  Where floor x is out of range,
+ * the result can still be minInt, for an x less than one (ceil) or one half (round)
+ * below it; there x + 1.0 and x + 0.5 are exact and floor of them gives the answer
+ * or raises Overflow.
+ *)
+fun ceil x = let
+      val f = floor x
+      in
+	if R64.== (real f, x) then f else Int.+ (f, 1)
+      end
+	handle Overflow => Int.- (~1, floor (R64.~ (x + 1.0)))
 
 fun trunc x = if R64.< (x, 0.0) then ceil x else floor x
 
 fun round x = let
     (* ties go to the nearest even number *)
-      val fl = floor(x+0.5)
-      val cl = ceil(x-0.5)
+      val f = floor x
+      val d = R64.- (x, real f)
       in
-	if fl=cl then fl
-	else if Word.andb(Word.fromInt fl, 0w1) = 0w1 then cl
-	else fl
+	if R64.< (d, 0.5) then f
+	else if R64.> (d, 0.5) orelse Word.andb(Word.fromInt f, 0w1) = 0w1
+	  then Int.+ (f, 1)
+	  else f
       end
+	handle Overflow => floor (x + 0.5)
 
 (* List *)
 exception Empty
diff --git a/base/system/smlnj/init/target64-inline.sml b/base/system/smlnj/init/target64-inline.sml
index 809777a..d952406 100644
--- a/base/system/smlnj/init/target64-inline.sml
+++ b/base/system/smlnj/init/target64-inline.sml
@@ -97,14 +97,14 @@ structure InlineT =
  * the CPS code generator.  Can also use InLine.round_real64_to_int.
  *)
 	local
-	(* the minInt (~4611686018427387904) and maxInt (4611686018427387904)
-	 * values converted to reals (with loss of precision).
+	(* minInt (~4611686018427387904 = ~2^62) and maxInt + 1 (2^62), which are
+	 * exact as reals; floor x is an int when rminInt <= x < rmaxInt.
 	 *)
-	  val rminInt = ~4611686018427390000.0
-	  val rmaxInt = 4611686018427390000.0
+	  val rminInt = ~4611686018427387904.0
+	  val rmaxInt = 4611686018427387904.0
 	in
 	fun floor (x : real) =
-	      if InLine.real64_le(rminInt, x) andalso InLine.real64_le(x, rmaxInt)
+	      if InLine.real64_le(rminInt, x) andalso InLine.real64_lt(x, rmaxInt)
 		then Assembly.A.floor x
 	      else if InLine.real64_eql(x, x)
 		then raise Assembly.Overflow
```

Tested with a fixed point for 32 and 64 bits.
