(* IEEEReal.setRoundingMode, and the functions of Real that use it. The
   divisor is in a ref, so that the division is done at run time.
   Run: sml bug.sml *)
fun modeName IEEEReal.TO_NEAREST = "TO_NEAREST" | modeName IEEEReal.TO_NEGINF = "TO_NEGINF"
  | modeName IEEEReal.TO_POSINF = "TO_POSINF" | modeName IEEEReal.TO_ZERO = "TO_ZERO"
fun show (name, got, expected) =
      print (concat [name, " = ", got, ", expected ", expected, ": ",
                     if got = expected then "ok" else "WRONG", "\n"])
fun under (mode, f) = let
      val () = IEEEReal.setRoundingMode mode
      val r = f ()
      in
        IEEEReal.setRoundingMode IEEEReal.TO_NEAREST; r
      end
val three = ref 3.0
fun third () = 1.0 / !three
val () = List.app (fn m =>
      show ("getRoundingMode () after setRoundingMode " ^ modeName m,
            under (m, fn () => modeName (IEEEReal.getRoundingMode ())), modeName m))
    [IEEEReal.TO_NEGINF, IEEEReal.TO_POSINF, IEEEReal.TO_ZERO]
val () = show ("1.0 / 3.0 under TO_POSINF > 1.0 / 3.0 under TO_NEGINF",
               Bool.toString (under (IEEEReal.TO_POSINF, third) > under (IEEEReal.TO_NEGINF, third)), "true")
fun r x = Real.fmt (StringCvt.FIX (SOME 1)) x
val () = show ("Real.realFloor 2.7", r (Real.realFloor 2.7), "2.0")
val () = show ("Real.realCeil 2.2", r (Real.realCeil 2.2), "3.0")
val () = show ("Real.realTrunc ~2.7", r (Real.realTrunc ~2.7), "~2.0")
val () = OS.Process.exit OS.Process.success
