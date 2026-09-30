fun both true true = 1 | both true false = 2 | both false true = 3 | both false false = 4
fun rows true _ = 1 | rows false true = 2 | rows false false = 3
val columns = fn (true,_) => 1 | (false,true) => 2 | (false,false) => 3
val _ = print (Int.toString (both false false + rows false false + columns (false,false)) ^ "\n")
