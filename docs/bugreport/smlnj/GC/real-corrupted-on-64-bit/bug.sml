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
