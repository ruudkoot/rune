datatype t = L | N of t list
exception E of string
fun f t = case t of L => raise E "leaf" | N ts => List.app f ts
val () = f (N [N [], L]) handle E s => print (s ^ "\n")
