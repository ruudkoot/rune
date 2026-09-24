(* An array of lists of ints, appended to and made into a vector: correct.
   It prints 7. *)
val a = Array.array (4, [] : int list)
val () = Array.update (a, 1, Array.sub (a, 1) @ [7])
val v = Array.vector a
val () = print (case Vector.sub (v, 1) of [x] => Int.toString x ^ "\n" | _ => "wrong\n")
