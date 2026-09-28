# Draft: comment on smlnj/legacy#299

Where: https://github.com/smlnj/legacy/issues/299

---

I think I found the cause: 64-bit functions share GC code whose roots do
not match theirs. It is a one-line fix in
`base/compiler/CodeGen/cpscompile/invokegc.sml`.

`emitLongJumpsToGCInvocation` lets an escaping function or continuation use
the GC code of an earlier one when `sameCallingConvention` says their roots
are the same:

```sml
	    ListPair.all eqR (b1, b2)
	      andalso eqR(ret1, ret2)
	      andalso ListPair.all eqR (i1, i2)
	      andalso ListPair.all eqF (f1, f2)
```

`ListPair.all` ignores the excess elements of the longer list, so root
lists of different lengths count as equal. For example, `[]` and `[xmm0]`
count as the same float roots. A function whose argument is an untagged
`Word64` or a real in a register can then share GC code that does not save
it, and the collection loses the value. Here that gives `0wxDEADBEEF` back
as a heap address.

With `ListPair.allEq`, the reproducer of this issue fails on 0 of 10 loads.
It fails on 7 to 10 of 10 with 110.99.9.

```diff
diff --git a/base/compiler/CodeGen/cpscompile/invokegc.sml b/base/compiler/CodeGen/cpscompile/invokegc.sml
index 699a7a6..c05b7ee 100644
--- a/base/compiler/CodeGen/cpscompile/invokegc.sml
+++ b/base/compiler/CodeGen/cpscompile/invokegc.sml
@@ -712,10 +712,14 @@ functor InvokeGC (
 	    | eqF (T.FLOAD(_,ea1,_), T.FLOAD(_,ea2,_)) = eqEA(ea1, ea2)
 	    | eqF _ = false
 	  in
-	    ListPair.all eqR (b1, b2)
+	  (* NOTE: `ListPair.all` ignores the excess elements of the longer list,
+	   * so we must use `ListPair.allEq` here; otherwise, a function with
+	   * float or untagged roots could share the GC code of one without them.
+	   *)
+	    ListPair.allEq eqR (b1, b2)
 	      andalso eqR(ret1, ret2)
-	      andalso ListPair.all eqR (i1, i2)
-	      andalso ListPair.all eqF (f1, f2)
+	      andalso ListPair.allEq eqR (i1, i2)
+	      andalso ListPair.allEq eqF (f1, f2)
 	  end
       | sameCallingConvention _ = false
 
```

A single-file program that shows the same thing with reals:

```sml
(* SML/NJ for 64 bits: a function that converts a real to its bits gives a
   wrong word (0wxFFF0000000000000 or a heap address) for some powers of two,
   when a garbage collection happens at the entry of the continuation that
   receives the mantissa of Real.toManExp in a register.
   Each of 300000 calls gets a power of two from 2^-1021 to 2^1023, made from
   its bits, and must give those bits back. A small allocation area makes
   collections frequent: sml @SMLalloc=128k bug.sml gets about 590 wrong, the
   default (512k) about 80, and 4m about 5. *)
val two52 : real = 4503599627370496.0
fun hex w = Word64.fmt StringCvt.HEX w
fun cast (w : Word64.word) : real =  (* the power of two whose bits are w *)
      Real.fromManExp {man = 0.5, exp = Word64.toInt (Word64.>> (w, 0w52)) - 1022}
fun bitsOf (x : real) : Word64.word =
  if Real.isNan x then 0wx7FF8000000000000
  else if not (Real.isFinite x) then 0wx7FF0000000000000
  else if Real.== (x, 0.0) then 0w0
  else
    let
      val {man, exp} = Real.toManExp x
      val e = exp + 1022
    in
      if e >= 1 then
        Word64.orb (Word64.<< (Word64.fromInt e, 0w52),
                    Word64.fromLargeInt (Real.toLargeInt IEEEReal.TO_NEAREST ((man * 2.0 - 1.0) * two52)))
      else
        Word64.fromLargeInt (Real.toLargeInt IEEEReal.TO_NEAREST (Real.fromManExp {man = man, exp = exp + 1074}))
    end
val bad = ref 0
fun go 0 = ()
  | go k = let val w = Word64.<< (Word64.fromInt (2 + k mod 2045), 0w52)
               val b = bitsOf (cast w)
           in (if b <> w then (bad := !bad + 1; if !bad <= 5 then print ("bits " ^ hex w ^ " -> " ^ hex b ^ "\n") else ()) else ()); go (k - 1) end
val () = go 300000
val () = print (Int.toString (!bad) ^ " of 300000 wrong\n")
val () = OS.Process.exit OS.Process.success
```

```
$ sml @SMLalloc=128k bug.sml            # 110.99.9, 64-bit
bits 31C0000000000000 -> FFF0000000000000
bits E20000000000000 -> 732032D40000
bits 7350000000000000 -> 732032D40000
bits 61B0000000000000 -> FFF0000000000000
bits 3E10000000000000 -> 732032D40000
587 of 300000 wrong
```

With the patch, built to a fixed point, it gives `0 of 300000 wrong` in
three runs with `@SMLalloc=128k` and one with the default. Its continuation
that receives `Real.toManExp`'s mantissa in `%xmm0` used to jump to GC code
that saved no float register. It now gets code of its own that boxes
`%xmm0` before the call and reloads it after.

Every 64-bit release I tried has the bug, from 110.94 on. The 2026 series
has no `invokegc.sml`. #381/#394 is a different bug: its program still
fails with this patch.
