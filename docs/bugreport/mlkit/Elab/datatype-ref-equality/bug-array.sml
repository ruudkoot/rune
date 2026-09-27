datatype t = T of (int -> int) array
val a = T (Array.array (1, fn x => x))
val () = print (if a = a andalso a <> T (Array.array (1, fn x => x)) then "equal when the same\n" else "wrong\n")
