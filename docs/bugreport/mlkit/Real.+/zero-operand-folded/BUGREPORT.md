# MLKit 4.7.23: `Real.+` with a zero operand is compiled away, so `0.0 + ~0.0` is `~0.0`

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `src/Compiler/Lambda/OptLambda.sml` is identical to
4.7.23's.

## Summary

* **The trigger:** an addition one of whose operands is the constant `0.0`
  (`0.0 + e`, `e + 0.0`), or a subtraction of the constant `~0.0`
  (`e - ~0.0`), where `e` is (or evaluates to) `~0.0`. The constant may
  come from inlining, as in `fun f x = 0.0 + x`.
* **What goes wrong:** the lambda optimiser replaces the whole expression by
  `e`, so the result is `~0.0` where IEEE arithmetic gives `0.0`. Computed at
  run time, `0.0 + ~0.0` is `0.0` in MLKit too; with `--no_optimiser` every
  line of the program below prints `0.0`.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html)
  says "The semantics of floating-point numbers should follow the IEEE
  standard 754-1985". There, the sum of two zeros of opposite sign is `+0`
  in every rounding mode except rounding towards negative infinity, and
  `x - y` is `x + (-y)`. `x + 0.0 = x` does not hold for `x = ~0.0`; only
  `x + ~0.0 = x` and `x - 0.0 = x` do (when rounding to nearest).

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* In IEEE arithmetic (rounding to nearest), 0.0 + ~0.0 and ~0.0 + 0.0 are
   0.0, and ~0.0 - ~0.0 is 0.0: only ~0.0 + ~0.0 is ~0.0. *)
fun sign r = if Real.signBit r then "~0.0" else "0.0"
fun show (what, r) = print (what ^ " = " ^ sign r ^ "   (expected 0.0)\n")

val negZero = ref ~0.0    (* a ~0.0 that the optimiser cannot see *)
val posZero = ref 0.0
fun addLeft x = 0.0 + x
fun addRight x = x + 0.0
fun subNegZero x = x - ~0.0

val () = show ("0.0 + ~0.0             ", 0.0 + ~0.0)
val () = show ("0.0 + !negZero         ", 0.0 + !negZero)
val () = show ("!negZero + 0.0         ", !negZero + 0.0)
val () = show ("addLeft (!negZero)     ", addLeft (!negZero))
val () = show ("addRight (!negZero)    ", addRight (!negZero))
val () = show ("subNegZero (!negZero)  ", subNegZero (!negZero))
val () = show ("!posZero + !negZero    ", !posZero + !negZero)
```

```
$ mlkit -o bug bug.mlb && ./bug
0.0 + ~0.0              = ~0.0   (expected 0.0)
0.0 + !negZero          = ~0.0   (expected 0.0)
!negZero + 0.0          = ~0.0   (expected 0.0)
addLeft (!negZero)      = ~0.0   (expected 0.0)
addRight (!negZero)     = ~0.0   (expected 0.0)
subNegZero (!negZero)   = ~0.0   (expected 0.0)
!posZero + !negZero     = 0.0   (expected 0.0)
```

The last line, where neither operand is a constant, is right. Built with
`mlkit --no_optimiser -o bug bug.mlb`, all seven lines print `0.0`.

## The cause

`src/Compiler/Lambda/OptLambda.sml` folds `__plus_f64` and `__minus_f64`
with a constant zero operand. `isZeroR` (line 1551) holds for both zeros,
since `Real.==(0.0, ~0.0)`:

```sml
      fun isZeroR s =
          case finiteRealFromString s of
              SOME r => Real.==(0.0,r)
            | _ => false
```

Both operands constant (line 1753; `constfold_f64_ext ()` is `false`):

```sml
                                    "__minus_f64" => if constfold_f64_ext() then opp Real.-
                                                     else if isZeroR s2 then Some (F64 s1)
                                                     else NONE
                                  | "__plus_f64" => if constfold_f64_ext() then opp Real.+
                                                    else if isZeroR s1 then Some (F64 s2)
                                                    else if isZeroR s2 then Some (F64 s1)
                                                    else NONE
```

One operand constant (line 1868):

```sml
                           | [e1, f as F64 s] =>
                             if not(constfold_f64()) then NONE
                             else (case name of
                                       "__minus_f64" => (if isZeroR s then Some e1 else NONE)   (* Notice: it is not safe in general to  *)
                                     | "__plus_f64" => (if isZeroR s then Some e1 else NONE)    (* simplify "0.0*e" to "0.0" as e may    *)
                                     ...
                           | [f as F64 s,e2] =>
                             if not(constfold_f64()) then NONE
                             else (case name of
                                       "__plus_f64" => (if isZeroR s then Some e2 else NONE)
```

`e + 0.0 => e`, `0.0 + e => e` and `e - ~0.0 => e` are wrong for
`e = ~0.0`. (`e + ~0.0 => e`, `~0.0 + e => e` and `e - 0.0 => e` are
identities when rounding to nearest; under `IEEEReal.TO_NEGINF`, which
MLKit supports with `IEEEReal.setRoundingMode`, `0.0 + ~0.0` and
`0.0 - 0.0` are `~0.0`, so even those are exact only in the default mode.)

## The fix

Keep only the identities: an added zero must be `~0.0`, a subtracted zero
`0.0`. Not tested (MLKit was not rebuilt here).

```diff
--- a/src/Compiler/Lambda/OptLambda.sml
+++ b/src/Compiler/Lambda/OptLambda.sml
@@
       fun isZeroR s =
           case finiteRealFromString s of
               SOME r => Real.==(0.0,r)
             | _ => false
+      (* x + ~0.0 = x and x - 0.0 = x, but x + 0.0 is 0.0 for x = ~0.0 *)
+      fun isNegZeroR s =
+          case finiteRealFromString s of
+              SOME r => Real.==(0.0,r) andalso Real.signBit r
+            | _ => false
+      fun isPosZeroR s =
+          case finiteRealFromString s of
+              SOME r => Real.==(0.0,r) andalso not (Real.signBit r)
+            | _ => false
@@
                                     "__minus_f64" => if constfold_f64_ext() then opp Real.-
-                                                     else if isZeroR s2 then Some (F64 s1)
+                                                     else if isPosZeroR s2 then Some (F64 s1)
                                                      else NONE
                                   | "__plus_f64" => if constfold_f64_ext() then opp Real.+
-                                                    else if isZeroR s1 then Some (F64 s2)
-                                                    else if isZeroR s2 then Some (F64 s1)
+                                                    else if isNegZeroR s1 then Some (F64 s2)
+                                                    else if isNegZeroR s2 then Some (F64 s1)
                                                     else NONE
@@
-                                       "__minus_f64" => (if isZeroR s then Some e1 else NONE)
-                                     | "__plus_f64" => (if isZeroR s then Some e1 else NONE)
+                                       "__minus_f64" => (if isPosZeroR s then Some e1 else NONE)
+                                     | "__plus_f64" => (if isNegZeroR s then Some e1 else NONE)
@@
-                                       "__plus_f64" => (if isZeroR s then Some e2 else NONE)
+                                       "__plus_f64" => (if isNegZeroR s then Some e2 else NONE)
```

This assumes that the string of a `~0.0` constant reads back with its sign
through `Real.fromString` of the compiler's host; if it does not, the
simplifications of `+` should be dropped altogether. Dropping all four is
also the choice that respects the rounding modes other than the default.

## Relation to Rune

The check `Real.+/zero-plus-negzero` of `tests/basis/real.sml`
(`eqR ("Real.+/zero-plus-negzero", 0.0, fn () => 0.0 + ~0.0)`) fails on
MLKit with "got ~0.0, expected 0.0"; `Real.+/negzero-plus-negzero` passes.
Proposed line of `tests/basis/deviations.txt`:

```
native:mlkit@* | Real.+/zero-plus-negzero | HOST-BUG | the optimiser compiles 0.0 + e and e + 0.0 as e, so 0.0 + ~0.0 is ~0.0, not 0.0 (with --no_optimiser it is 0.0)
```
