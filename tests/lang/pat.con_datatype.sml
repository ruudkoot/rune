datatype t = A | B of int | C of string * int
fun f A = "A" | f (B n) = "B" ^ Int.toString n | f (C (s, n)) = "C" ^ s ^ Int.toString n
val () = print (f A ^ f (B 1) ^ f (C ("s", 2)) ^ "\n")
fun opt (SOME (SOME x)) = x | opt (SOME NONE) = ~1 | opt NONE = ~2
val () = print (Int.toString (opt (SOME (SOME 5))) ^ Int.toString (opt (SOME NONE)) ^ Int.toString (opt NONE) ^ "\n")
fun bools (true, false) = 1 | bools (false, true) = 2 | bools _ = 0
val () = print (Int.toString (bools (true, false) + bools (false, true) + bools (true, true)) ^ "\n")
