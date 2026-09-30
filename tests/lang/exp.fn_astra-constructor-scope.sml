datatype t = C of int | D
val alias = C
val x = alias 20
fun C n = n+2
val _ = print (Int.toString (case x of D => 0 | alias => C 40) ^ "\n")
fun localValue n = let datatype t = C of int
                      val f = fn k => C (n+k)
                  in case f 2 of C x => x end
val _ = print (Int.toString (localValue 40) ^ "\n")
datatype t = C of int
val _ = print (Int.toString (case C 42 of C n => n) ^ "\n")
