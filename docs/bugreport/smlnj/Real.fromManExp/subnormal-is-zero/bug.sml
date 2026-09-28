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
