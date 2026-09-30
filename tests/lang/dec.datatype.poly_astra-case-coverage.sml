datatype t = A of bool * bool | B of unit
fun f x = case x of A (true,_) => 1 | A (false,true) => 2 | A (false,false) => 3 | B () => 4
val _ = print (Int.toString (f (A (false,false)) + f (B ())) ^ "\n")
