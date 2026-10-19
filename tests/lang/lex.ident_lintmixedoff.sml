(* a name that mixes scripts (UTS #39): x and lambda; a name of two
   parts, each of one script, does not warn *)
val xλ = 1
val get_λ = 2
val () = print (Int.toString (xλ + get_λ) ^ "\n")
