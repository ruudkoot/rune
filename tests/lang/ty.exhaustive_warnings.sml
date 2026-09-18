(* Section 4.11: matches are checked for exhaustiveness and redundancy *)
datatype t = A | B of int | C of t * t
fun f A = 0
  | f (B n) = n
fun g A = 1 | g (B _) = 2 | g (C (A, _)) = 3
val h = fn (x, true) => x | (x, false) => x
fun k [] = 0 | k [_] = 1 | k (_ :: _ :: _) = 2 | k [_, _] = 3      (* redundant last rule *)
val (SOME z) = SOME 1                                              (* at top level: not reported *)
val () = let val (SOME y) = SOME 2 in print (Int.toString (y + z) ^ "\n") end
val () = (raise Fail "x") handle Fail _ => print "handled\n" | Fail "y" => print "never\n"
val () = print (Int.toString (f (B 4) + g A + h (1, true) + k [1, 2]) ^ "\n")
fun const 1 = "one" | const 2 = "two"
val () = print (const 1 ^ "\n")
fun two A A = 0 | two _ (B _) = 1
val () = print (Int.toString (two A A) ^ "\n")
