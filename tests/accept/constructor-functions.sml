datatype t = A of int | B of int
fun apply c x = c x
fun tail x = A x
fun choose flag = if flag then A else B
val a = apply (choose true) 20
val b = tail 22
val _ = print (Int.toString (case (a,b) of (A x,A y) => x+y | _ => 0) ^ "\n")
