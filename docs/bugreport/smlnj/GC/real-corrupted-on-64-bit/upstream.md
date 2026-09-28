# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** 64-bit: a garbage collection corrupts a value held by a function (single-file reproducer; related to #299 and #381?)

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Linux |
| OS Version | Ubuntu 24.04 (WSL2), kernel 6.18 |
| Processor | x86-64 (64-bit) |
| System Component | Core system |
| Severity | Critical |
| Also present in the "development" version? | Unknown (2026.3 has the new `CPSTransFn` of #394; not tried) |

### Description

A pure function that computes the bits of a real (with `Real.toManExp`,
`Real.fromManExp`, `Real.toLargeInt` and `Word64` operations) now and then
returns a wrong word. The word is `0wxFFF0000000000000`, which it would give
if `Real.toManExp`'s mantissa read as 0.0, or a heap address. The same call
on the same number is right a moment later, and which calls go wrong
changes from run to run.

It depends on garbage collection: 82 of 300,000 calls at the default
settings, and 588 with `@SMLalloc=128k`. Every 64-bit release I tried from
110.96 to 110.99.9 has it; the 32-bit build does not. In a larger program
the process also stops with "Fatal error -- bogus fault" or "bogus
overflow fault".

This may be what #299 sees (a value not preserved across a collection), or
#381/#394 (a record mixing raw 64-bit values and pointers after arity
lowering). The program is a single file without functors or `Pack`
structures.

### Transcript

```
$ sml @SMLalloc=128k bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
bits 47A0000000000000 -> 77DCBF85D000000
bits 3F00000000000000 -> 772FE1740000
bits 2D60000000000000 -> FFF0000000000000
bits 9C0000000000000 -> 772FE1740000
bits 6EF0000000000000 -> 772FE1740000
588 of 300000 wrong
```

### Expected Behavior

`0 of 300000 wrong`.

### Steps to Reproduce

```sml
(* SML/NJ for 64 bits: a function that converts a real to its bits gives
   0wxFFF0000000000000 for some powers of two, after a garbage collection.
   Each of 300000 calls gets a power of two from 2^-1021 to 2^1023, made from
   its bits, and must give those bits back. Run with a small allocation area,
   which makes collections frequent: sml @SMLalloc=128k bug.sml
   (with the default area it fails less often; with 512k or more, not at all) *)
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

### Additional Information

What I found without locating the fault:
* The failures need the function's exact shape. Binding its intermediate
  values to names, or dropping the `isNan` or `isFinite` test or either
  branch, makes them go away.
* No `Control.CG` flag I tried changes them (flattenargs, extraflatten,
  etasplit, uncurry, betaexpand, dropargs, rounds, spillGen, ifidiom,
  lambdaprop, invariant). `closureStrategy := 1` changes the count, and
  `checkCPS` reports nothing.
* In the CPS after closure conversion, the continuations carry the mantissa
  (`R64`) and the shifted exponent (`I64`) unboxed across the calls that
  allocate, in `RK_FCONT`/`RK_RAWBLOCK` closure records or in float
  registers that `invokegc.sml` packs into a raw record around a
  collection.
