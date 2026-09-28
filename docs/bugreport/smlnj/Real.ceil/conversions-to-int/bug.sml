(* Real.floor, ceil, trunc and round near integers and at the ends of int.
   Each expected value is the exact mathematical result, or Overflow when that
   does not fit int (31 bits on SML/NJ for 32 bits, 63 for 64); the reals are
   made exactly. Run: sml bug.sml *)
fun p2 n = Real.fromManExp {man = 1.0, exp = n}
fun big s = valOf (IntInf.fromString s)
fun fits v = case (Int.minInt, Int.maxInt) of
               (SOME lo, SOME hi) => Int.toLarge lo <= v andalso v <= Int.toLarge hi
             | _ => true
fun show (name, f, value) =
      let val expected = if fits (big value) then value else "Overflow"
          val got = (IntInf.toString (Int.toLarge (f ()))) handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
val minInt = real (valOf Int.minInt)
val () = show ("ceil minPos", fn () => Real.ceil Real.minPos, "1")
val () = show ("ceil (nextAfter (3.0, 4.0))", fn () => Real.ceil (Real.nextAfter (3.0, 4.0)), "4")
val () = show ("ceil 1.0E~20", fn () => Real.ceil 1.0E~20, "1")
val () = show ("trunc (~(2^62) + 512.0)", fn () => Real.trunc (~(p2 62) + 512.0), "~4611686018427387392")
val () = show ("floor (2^62)", fn () => Real.floor (p2 62), "4611686018427387904")
val () = show ("floor (~(2^62) - 2048.0)", fn () => Real.floor (~(p2 62) - 2048.0), "~4611686018427389952")
val () = show ("trunc (~(2^62))", fn () => Real.trunc (~(p2 62)), "~4611686018427387904")
val () = show ("round (2^62)", fn () => Real.round (p2 62), "4611686018427387904")
val () = show ("round (real minInt - 0.5)", fn () => Real.round (minInt - 0.5), IntInf.toString (Int.toLarge (valOf Int.minInt)))
val () = show ("round (2^52 + 1.0)", fn () => Real.round (p2 52 + 1.0), "4503599627370497")
val () = show ("round 2.5", fn () => Real.round 2.5, "2")
val () = show ("round ~2.5", fn () => Real.round ~2.5, "~2")
val () = OS.Process.exit OS.Process.success
