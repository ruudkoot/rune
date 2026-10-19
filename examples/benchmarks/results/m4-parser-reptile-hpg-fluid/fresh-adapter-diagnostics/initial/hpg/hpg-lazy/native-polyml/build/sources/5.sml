(* Selected finite normal binary32 arithmetic, represented exactly in binary64.
   Mandel2's operands/results are zero or normal; reference bit fixtures verify
   the actual domain. General subnormal/overflow/transcendental support is not
   claimed by this workload helper. *)
structure BenchMandelSingle =
struct
  fun round r =
    if Real.== (r, 0.0) then r
    else if not (Real.isFinite r) then raise Domain
    else
      let val negative = Real.signBit r
          val {man, exp} = Real.toManExp (Real.abs r)
          val _ = if exp < ~125 orelse exp > 128 then raise Domain else ()
          val significand = Real.toInt IEEEReal.TO_NEAREST (man * 16777216.0)
          val value = Real.fromManExp {man = Real.fromInt significand, exp = exp - 24}
      in if negative then ~value else value end
  fun add (a, b) = round (a + b)
  fun sub (a, b) = round (a - b)
  fun mul (a, b) = round (a * b)
  fun divide (a, b) = round (a / b)
end
