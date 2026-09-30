fun diagonal true true = 1 | diagonal false false = 2
fun redundant true _ = 1 | redundant false true = 2 | redundant true false = 3 | redundant false false = 4
val f = fn [] => 1 | _ => 2 | [x] => x
fun incomplete true [] = 1 | incomplete false [] = 2
val _ = print (Int.toString (diagonal false false + redundant false false + f [4] + incomplete true []) ^ "\n")
