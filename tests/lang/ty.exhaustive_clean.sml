(* exhaustive matches produce no report *)
datatype t = A | B of int | C of t * t
fun size A = 1 | size (B _) = 1 | size (C (l, r)) = size l + size r
fun opt NONE = 0 | opt (SOME n) = n
fun pair (0, _) = 0 | pair (_, 0) = 0 | pair (a, b) = a * b
fun rcd {a = true, b} = b | rcd {a = false, ...} = 0
fun lst [] = 0 | lst [x] = x | lst (x :: y :: _) = x + y
fun r (ref n) = n
val () = print (Int.toString (size (C (A, B 1)) + opt (SOME 2) + pair (2, 3) + rcd {a = true, b = 4} + lst [5, 6] + r (ref 7)) ^ "\n")
val () = ((raise Fail "z") handle Fail s => print (s ^ "\n") | _ => print "other\n")
