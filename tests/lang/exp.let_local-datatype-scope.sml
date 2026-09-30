val n = let datatype t = C of int val x = C 42 in case x of C i => i end
val f = let datatype t = C | D val x = C in fn () => case x of C => n | D => 0 end
val () = print (Int.toString (f ()) ^ "\n")
