val f = fn true => fn true => 1 | false => 2
val g = fn true => (fn true => 3 | false => 4) | false => (fn _ => 5)
fun h true = (case false of true => 6 | false => 7) | h false = 8
val j = fn true => case false of true => 9 | false => 10
val k = case true of true => (fn true => 11 | false => 12) | false => (fn _ => 13)
fun m true = (fn true => 14 | false => 15) | m false = (fn _ => 16)
val _ = print (Int.toString (f true false + g false true + h true + j true + k false + m false true) ^ "\n")
