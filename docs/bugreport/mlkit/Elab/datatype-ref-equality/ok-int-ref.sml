datatype t = T of int ref
val a = T (ref 1)
val () = print (if a = a andalso a <> T (ref 1) then "equal when the same\n" else "wrong\n")
