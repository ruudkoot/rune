(* Real.round is the nearest int, ties to even, and Real.realRound the
   nearest whole real, whatever rounding mode IEEEReal.setRoundingMode has
   set: the greatest real below one half, its negation, the ties, and the
   whole reals from 2^52, where adding one half to an odd one rounds. Each
   is printed with each of the four modes set; the arguments stay below
   2^62, so that an int of 63 or of 64 bits holds every result. *)
fun pow2 e = Real.fromManExp {man = 1.0, exp = e}
val cases =
  [("below 1/2", 0.5 - pow2 ~54), ("above -1/2", ~ (0.5 - pow2 ~54)), ("1/2", 0.5), ("-1/2", ~0.5),
   ("3/2", 1.5), ("-3/2", ~1.5), ("5/2", 2.5), ("-5/2", ~2.5),
   ("2^52+1", pow2 52 + 1.0), ("-2^52-1", ~ (pow2 52 + 1.0)), ("2^52-1/2", pow2 52 - 0.5), ("2^52-3/2", pow2 52 - 1.5),
   ("2^53", pow2 53), ("-2^53", ~ (pow2 53)), ("below 2^62", pow2 62 - pow2 9), ("-2^62", ~ (pow2 62)),
   ("nan", Real.posInf - Real.posInf), ("inf", Real.posInf), ("-inf", Real.negInf)]
val modes = [("nearest", IEEEReal.TO_NEAREST), ("down", IEEEReal.TO_NEGINF),
             ("up", IEEEReal.TO_POSINF), ("zero", IEEEReal.TO_ZERO)]
fun rounded x = Int.toString (Real.round x) handle Overflow => "Overflow" | Domain => "Domain"
fun whole r = if Real.isFinite r then Real.fmt (StringCvt.FIX (SOME 0)) r else Real.toString r
(* the results, worked out with the mode set and printed with the default one *)
val results =
  List.map (fn (m, mode) =>
              (IEEEReal.setRoundingMode mode;
               (m, List.map (fn (c, x) => (c, rounded x, Real.realRound x)) cases)
               before IEEEReal.setRoundingMode IEEEReal.TO_NEAREST))
           modes
val () = List.app (fn (m, rs) =>
                     List.app (fn (c, n, r) => print (m ^ " " ^ c ^ ": " ^ n ^ " " ^ whole r ^ "\n")) rs)
                  results
