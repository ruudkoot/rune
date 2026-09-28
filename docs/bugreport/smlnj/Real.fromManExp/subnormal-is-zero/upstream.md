# Draft: comment on smlnj/legacy#254

Where: https://github.com/smlnj/legacy/issues/254 (closed as fixed in
110.99.3; a comment, or ask for it to be reopened).

---

This is still present in 110.99.9 on the 32-bit and 64-bit builds, Linux and
Windows, and the code is the same in smlnj/smlnj. The example above,
`Real.fromManExp {man = 1.0, exp = ~1021}`, is still `0.0`, and so is every
result below 2^-1021, `Real.minPos` included.

In `Real/real64.sml`, for `exp < ~1020`, the loop halves `1020-e` times
after scaling by 2^-1020, where it should halve `~1020-e` times. It halves
2,040 times too often and always reaches zero. With only that corrected, two
smaller faults would remain:
* halving rounds at every step once the value is subnormal, so
  `{man = 0.6875, exp = ~1073}` would be `2 * minPos` rather than `minPos`;
* `0.0` below 2^-1200 drops the sign of a negative `man`.

The loop is needed because `scalb` cannot produce a subnormal number on
amd64: `AMD64.prim.asm` returns +0 for a subnormal result and returns a
subnormal argument unchanged. The patch below scales into the normal range,
where `scalb` is right on every target, and multiplies once by
`minNormalPos`. That rounds once, in the current mode, and keeps the sign.
It is against legacy `main` (`6ed5a0a`) and also applies to 110.99.9; the
smlnj/smlnj code is identical:

```diff
diff --git a/base/system/Basis/Implementation/Real/real64.sml b/base/system/Basis/Implementation/Real/real64.sml
index 8646062..1b4188e 100644
--- a/base/system/Basis/Implementation/Real/real64.sml
+++ b/base/system/Basis/Implementation/Real/real64.sml
@@ -186,10 +186,13 @@ structure Real64Imp : REAL =
                                  in f(e-1020,  Assembly.A.scalb(m,1020))
                                 end
                     else if e < ~1020
-                         then if e < ~1200 then 0.0
-                           else let fun f(i,x) = if i=0 then x else f(i-1, x*0.5)
-                                 in f(1020-e, Assembly.A.scalb(m, ~1020))
-                                end
+                         (* the result is below 2^-1021: scale `m` within the
+                          * normal range, which scalb handles on every target,
+                          * and multiply by 2^-1022 once, so that the result is
+                          * rounded once and an underflow keeps the sign
+                          *)
+                         then Assembly.A.scalb(m, if e < ~1222 then ~200 else e + 1022)
+                                * minNormalPos
                          else Assembly.A.scalb(m,e)  (* This is the common case! *)
                   else let
                     val {man=m', exp=e'} = toManExp m
```

Program (each expected value is made by halving a normal number, which is
exact):

```sml
(* Real.fromManExp below the least normal exponent. Each expected value is
   made by halving a normal real, which is exact. Run: sml bug.sml *)
fun halve (x, 0) = x | halve (x, n) = halve (x / 2.0, n - 1)
fun show (m, e, expected) =
      let val got = Real.fromManExp {man = m, exp = e}
      in print (concat ["fromManExp {man = ", Real.toString m, ", exp = ", Int.toString e,
                        "} = ", Real.fmt (StringCvt.SCI (SOME 16)) got, ", expected ",
                        Real.fmt (StringCvt.SCI (SOME 16)) expected, ": ",
                        if Real.== (got, expected) andalso Real.signBit got = Real.signBit expected
                          then "ok" else "WRONG", "\n"])
      end
val two1000 = Real.fromManExp {man = 0.5, exp = ~999}   (* 2^-1000, normal *)
val () = show (1.0, ~1021, halve (two1000, 21))          (* 2^-1021 *)
val () = show (0.5, ~1021, halve (two1000, 22))          (* 2^-1022 = minNormalPos *)
val () = show (0.5, ~1073, halve (two1000, 74))          (* 2^-1074 = minPos *)
val () = show (~0.75, ~1030, ~ (halve (0.75 * two1000, 30)))
val () = show (0.6875, ~1073, Real.minPos)               (* 1.375 * minPos rounds to minPos *)
val () = show (~1.0, ~1300, ~0.0)
val () = OS.Process.exit OS.Process.success
```

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
fromManExp {man = 1, exp = ~1021} = 0.0000000000000000E0, expected 4.4501477170144030E~308: WRONG
fromManExp {man = 0.5, exp = ~1021} = 0.0000000000000000E0, expected 2.2250738585072014E~308: WRONG
fromManExp {man = 0.5, exp = ~1073} = 0.0000000000000000E0, expected 5.0000000000000000E~324: WRONG
fromManExp {man = ~0.75, exp = ~1030} = ~0.0000000000000000E0, expected ~6.5187710698453000E~311: WRONG
fromManExp {man = 0.6875, exp = ~1073} = 0.0000000000000000E0, expected 5.0000000000000000E~324: WRONG
fromManExp {man = ~1, exp = ~1300} = 0.0000000000000000E0, expected ~0.0000000000000000E0: WRONG
```

Tested with a fixed point for 32 and 64 bits, and with cross-compiled
x86-unix and x86-win32 boot files.
