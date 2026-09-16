datatype t = A of int | B
val extract = fn A n => n
fun add (A x) (A y) = x+y
val part = add (A 20)
val _ = print (Int.toString (part (A 22)) ^ "\n")
val _ = print (Int.toString (extract (A 42)) ^ "\n")
val A answer = A 42
val _ = print (Int.toString answer ^ "\n")
