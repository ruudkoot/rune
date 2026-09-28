(* Real.nextAfter at the bottom of the range: the step down from the least
   normal real, a step down between subnormal reals, and the step from a zero
   towards an infinity of the other sign. Run: sml bug.sml *)
fun s r = Real.fmt (StringCvt.SCI (SOME 16)) r
fun show (name, r, e) =
      print (concat [name, " = ", s r, ", expected ", s e, ": ",
                     if Real.== (r, e) andalso Real.signBit r = Real.signBit e then "ok" else "WRONG", "\n"])
val () = show ("nextAfter (minNormalPos, 0.0)", Real.nextAfter (Real.minNormalPos, 0.0), Real.minNormalPos - Real.minPos)
val () = show ("nextAfter (~minNormalPos, 1.0)", Real.nextAfter (~Real.minNormalPos, 1.0), ~(Real.minNormalPos - Real.minPos))
val () = show ("nextAfter (2.0 * minPos, 0.0)", Real.nextAfter (2.0 * Real.minPos, 0.0), Real.minPos)
val () = show ("nextAfter (0.0, negInf)", Real.nextAfter (0.0, Real.negInf), ~Real.minPos)
val () = show ("nextAfter (~0.0, posInf)", Real.nextAfter (~0.0, Real.posInf), Real.minPos)
val () = OS.Process.exit OS.Process.success
