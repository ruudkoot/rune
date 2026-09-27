# MLKit 4.7.23: `Real.ceil` and `Real.trunc` fail at `minInt`, and `ceil` wraps around above `maxInt`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** Poly/ML meets it; SML/NJ gets `ceil` and `trunc` of `minInt` wrong in another way, and MLton's `int` has 32 bits.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `src/Runtime/Math.c` and `src/Runtime/Math.h` are
identical to 4.7.23's.

## Summary

* **The trigger:** `Real.ceil` or `Real.trunc` (and so `Real.toInt
  IEEEReal.TO_POSINF` and `TO_ZERO`) of `real minInt` = -2^62, or of a real
  that rounds to it such as `real minInt - 0.5`; `Real.ceil` of 2^62 =
  `real maxInt + 1.0`, the first real above `maxInt`.
* **What goes wrong:** `ceil` and `trunc` of -2^62 raise `Overflow`,
  although the result `minInt` is an `int`; `ceil` of 2^62 returns
  `minInt` (the tagged result wraps around) instead of raising `Overflow`.
  `floor` and `round`, written in SML in `basis/Real.sml`, get both right.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html):
  "ceil produces ceil(r), the smallest int not less than r. trunc rounds r
  towards zero. ... They raise Overflow if the resulting value cannot be
  represented as an int"; `toInt` with `TO_POSINF` and `TO_ZERO` is `ceil`
  and `trunc`.

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend, where `int` has 63 bits (`Int.precision = SOME 63`, tagged).
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* Int.minInt = ~2^62 is a real; Int.maxInt + 1 = 2^62 is the first real
   above Int.maxInt. *)
fun show (what, f) =
    print (what ^ " = " ^ (Int.toString (f ()) handle Overflow => "Overflow") ^ "\n")
val minInt = valOf Int.minInt
val m = Real.fromInt minInt                      (* ~2^62, exact *)
val above = Real.fromInt (valOf Int.maxInt) + 1.0 (* 2^62, exact *)

val () = print ("Int.minInt = " ^ Int.toString minInt ^ ", Int.precision = "
                ^ Int.toString (valOf Int.precision) ^ "\n\n")
val () = print "expected ~4611686018427387904:\n"
val () = show ("  Real.floor (real minInt)        ", fn () => Real.floor m)
val () = show ("  Real.round (real minInt)        ", fn () => Real.round m)
val () = show ("  Real.ceil (real minInt)         ", fn () => Real.ceil m)
val () = show ("  Real.trunc (real minInt)        ", fn () => Real.trunc m)
val () = show ("  Real.ceil (real minInt - 0.5)   ", fn () => Real.ceil (m - 0.5))
val () = show ("  Real.trunc (real minInt - 0.5)  ", fn () => Real.trunc (m - 0.5))
val () = show ("  Real.toInt TO_POSINF (real minInt)", fn () => Real.toInt IEEEReal.TO_POSINF m)
val () = show ("  Real.toInt TO_ZERO (real minInt)  ", fn () => Real.toInt IEEEReal.TO_ZERO m)
val () = print "expected Overflow:\n"
val () = show ("  Real.floor 2^62                 ", fn () => Real.floor above)
val () = show ("  Real.trunc 2^62                 ", fn () => Real.trunc above)
val () = show ("  Real.ceil 2^62                  ", fn () => Real.ceil above)
val () = show ("  Real.toInt TO_POSINF 2^62       ", fn () => Real.toInt IEEEReal.TO_POSINF above)
```

```
$ mlkit -o bug bug.mlb && ./bug
Int.minInt = ~4611686018427387904, Int.precision = 63

expected ~4611686018427387904:
  Real.floor (real minInt)         = ~4611686018427387904
  Real.round (real minInt)         = ~4611686018427387904
  Real.ceil (real minInt)          = Overflow
  Real.trunc (real minInt)         = Overflow
  Real.ceil (real minInt - 0.5)    = Overflow
  Real.trunc (real minInt - 0.5)   = Overflow
  Real.toInt TO_POSINF (real minInt) = Overflow
  Real.toInt TO_ZERO (real minInt)   = Overflow
expected Overflow:
  Real.floor 2^62                  = Overflow
  Real.trunc 2^62                  = Overflow
  Real.ceil 2^62                   = ~4611686018427387904
  Real.toInt TO_POSINF 2^62        = ~4611686018427387904
```

(`real minInt - 0.5` is `real minInt`: the reals next to -2^62 are 512
above and 1024 below it.)

## The cause

`basis/Real.sml` calls the runtime for `ceil` and `trunc`
(`prim ("ceilFloat", ...)`, `prim ("truncFloat", ...)`). In
`src/Runtime/Math.c` they compare the argument with bounds written as
`double` constants of `src/Runtime/Math.h`:

```c
#define Max_Int 4611686018427387903       /* remember [i] = 2 * i + 1 */
#define Min_Int -4611686018427387904
#define Max_Int_d 4611686018427387903.0
#define Min_Int_d -4611686018427387904.0
```

`Max_Int_d` is not a double: it rounds to 2^62. `Min_Int_d - 1.0` rounds
back to `Min_Int_d`. So in `ceilFloat` (line 579)

```c
  if( arg >= 0.0 )
    {
      if( arg > Max_Int_d ) goto raise_ceil;
      i = (ssize_t) arg;
      if( arg > ((double) i) ) i += 1;
    }
  else
    {
      if( arg <= (Min_Int_d - 1.0) ) goto raise_ceil;
      i = (ssize_t) arg;
    }
  return convertIntToML(i);
```

2^62 passes the test `arg > Max_Int_d` (2^62 > 2^62 is false), `i` becomes
2^62, and `convertIntToML` (2 * i + 1) overflows into `minInt`; and -2^62
fails `arg <= Min_Int_d - 1.0` (-2^62 <= -2^62), so the valid `minInt`
raises `Overflow`. `truncFloat` (line 566) has the same lower bound:

```c
  if ((r >= (Max_Int_d + 1.0)) || (r <= (Min_Int_d - 1.0)))
    {
      raise_exn(ctx,(uintptr_t)&exn_OVERFLOW);
    }
```

(its upper bound is right, because `Max_Int_d + 1.0` is 2^62 as well). The
untagged configuration (`Max_Int_d 9223372036854775807.0`) has the same
problem one bit higher.

## The fix

Compare with 2^(p-1), which is `-(double)Min_Int` exactly: no double lies
between `maxInt` and 2^(p-1), nor between -2^(p-1) - 1 and -2^(p-1).

```diff
--- a/src/Runtime/Math.c
+++ b/src/Runtime/Math.c
@@ truncFloat
   double r;
+  const double lim = -(double)Min_Int;   /* 2^(p-1), exact */
 
   r = get_d(f);
-  if ((r >= (Max_Int_d + 1.0)) || (r <= (Min_Int_d - 1.0)))
+  if ((r >= lim) || (r < -lim))
     {
       raise_exn(ctx,(uintptr_t)&exn_OVERFLOW);
     }
@@ ceilFloat
   double arg;
   ssize_t i;
+  const double lim = -(double)Min_Int;   /* 2^(p-1), exact */
 
   arg = get_d(f);
 
+  if( arg >= lim || arg < -lim ) goto raise_ceil;
   if( arg >= 0.0 )
     {
-      if( arg > Max_Int_d ) goto raise_ceil;
       i = (ssize_t) arg;
       if( arg > ((double) i) ) i += 1;
     }
   else
     {
-      if( arg <= (Min_Int_d - 1.0) ) goto raise_ceil;
       i = (ssize_t) arg;
     }
```

The runtime was not rebuilt here. The old and the new comparisons were
checked in a small C program on 2^62, 2^62 - 512, -2^62, -2^62 - 0.5,
-2^62 - 1024 and ±1e300: the new ones raise `Overflow` exactly when the
mathematical result does not fit 63 bits, the old ones do not (they accept
2^62 for `ceil` and reject -2^62 for both).

## Relation to Rune

The checks of `tests/basis/real.sml` that show it, all written for any
`Int.precision` (for p > 53, `real minInt - 0.5` is `real minInt`):
`Real.ceil/Overflow-above-maxInt` and
`Real.toInt/Overflow-TO_POSINF-above-maxInt` ("no exception raised");
`Real.ceil/minInt`, `Real.trunc/minInt`, `Real.ceil/minInt-minus-half`,
`Real.trunc/minInt-minus-half`, `Real.toInt/TO_POSINF-minInt` and
`Real.toInt/TO_ZERO-minInt` ("raised an exception, expected
~4611686018427387904"). Proposed lines of `tests/basis/deviations.txt`:

```
native:mlkit@* | Real.ceil/Overflow-above-maxInt | HOST-BUG | ceil of 2^62, the first real above maxInt, is minInt, not Overflow: the runtime compares with maxInt written as a double, which is 2^62
native:mlkit@* | Real.toInt/Overflow-TO_POSINF-above-maxInt | HOST-BUG | toInt TO_POSINF is ceil, which gives minInt for 2^62 instead of raising Overflow
native:mlkit@* | Real.ceil/minInt* | HOST-BUG | ceil of minInt = ~2^62 (and of minInt - 0.5, the same real) raises Overflow: the runtime compares with minInt - 1.0, which rounds to minInt
native:mlkit@* | Real.trunc/minInt* | HOST-BUG | trunc of minInt = ~2^62 (and of minInt - 0.5, the same real) raises Overflow: the runtime compares with minInt - 1.0, which rounds to minInt
native:mlkit@* | Real.toInt/TO_[PZ]*-minInt | HOST-BUG | toInt TO_POSINF and TO_ZERO are ceil and trunc, which raise Overflow for minInt = ~2^62
```
