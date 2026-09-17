datatype t = A | B of int
datatype u = datatype t
fun f A = 0 | f (B n) = n
val x : u = B 5
val () = print (Int.toString (f x + f A) ^ "\n")
structure S = struct datatype v = C | D end
datatype w = datatype S.v
val () = print (Bool.toString (C = S.C) ^ "\n")
