(* An array of lists of pairs made into a vector, the element written as a
   literal rather than taken from another list: correct. It prints 7. *)
val a = Array.array (4, [] : (string * int) list)
val () = Array.update (a, 1, [("x", 7)])
val v = Array.vector a
fun find [] = NONE | find ((k, n) :: r) = if k = "x" then SOME n else find r
val () = print (case find (Vector.sub (v, 1)) of SOME n => Int.toString n ^ "\n" | NONE => "none\n")
