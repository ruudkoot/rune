# MLKit 4.7.23: `Math.ln` and `Math.log10` of a NaN are `~inf`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton, SML/NJ and Poly/ML return a NaN.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Math.sml` is identical to 4.7.23's.

## Summary

* **The trigger:** `Math.ln nan` or `Math.log10 nan`.
* **What goes wrong:** both return `~inf`.
* **Required behaviour:** the
  [Basis `MATH` specification](https://smlfamily.github.io/Basis/math.html):
  "In the functions below, unless specified otherwise, if any argument is a
  NaN, the return value is a NaN"; `ln` and `log10` specify only "If x < 0,
  they return NaN; if x = 0, they return -infinity; if x is infinity, they
  return infinity."

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
val nan = Real.posInf - Real.posInf
fun show (what, r) = print (what ^ " = " ^ Real.toString r ^ "   (expected nan)\n")
val () = show ("Math.ln nan   ", Math.ln nan)
val () = show ("Math.log10 nan", Math.log10 nan)
val () = print ("for comparison, Math.exp nan = " ^ Real.toString (Math.exp nan) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
Math.ln nan    = ~inf   (expected nan)
Math.log10 nan = ~inf   (expected nan)
for comparison, Math.exp nan = nan
```

## The cause

`basis/Math.sml` defines its own equality through `compare`, which answers
`EQUAL` when neither `<` nor `>` holds, as for a NaN:

```sml
  fun compare (x, y: real) =
    if x<y then LESS else if x>y then GREATER else EQUAL

  infix ==
  fun op == (x, y) = case compare (x,y)
		       of EQUAL => true
			| _ => false
```

and `ln` tests for a zero first (line 46):

```sml
     fun ln r = if r == 0.0 then mkNegInf()
		else if r == mkPosInf() then mkPosInf()
		     else let val r = ln' r
			  in if r == mkNegInf() then mkNaN()
			     else r
			  end
     fun log10 r = ln r / ln' 10.0
```

so `nan == 0.0` is `true` and `ln nan` is `mkNegInf ()`; `log10` divides
that by `ln 10`.

## The fix

Return a NaN argument first. (`pow`, which also uses `==`, relies on
`y == posInf` being true for a NaN `y` to give `pow (1.0, nan) = nan`, as
the specification wants, so `==` itself is better left alone.)

```diff
--- a/basis/Math.sml
+++ b/basis/Math.sml
@@
-     fun ln r = if r == 0.0 then mkNegInf()
+     (* == holds for a NaN: take it out first *)
+     fun ln r = if isNan r then r
+		else if r == 0.0 then mkNegInf()
 		else if r == mkPosInf() then mkPosInf()
```

(`isNan` is defined at the top of `Math.sml`.) Tested as a wrapper in a
program built with MLKit 4.7.23, with `Math` shadowed: all 256 checks of
Rune's `tests/basis/math.sml` pass with it. The patch of the library itself
was not built.

## Relation to Rune

The checks `Math.ln/nan` and `Math.log10/nan` of `tests/basis/math.sml`
fail on MLKit with "got ~inf, expected nan". Proposed line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | Math.l*/nan | HOST-BUG | ln and log10 of a NaN are ~inf: ln tests r == 0.0 first, with an == that holds when neither < nor > does
```
