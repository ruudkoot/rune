datatype t = T of (int -> int) ref
val a = T (ref (fn x => x))
val () = print (if a = a andalso a <> T (ref (fn x => x)) then "equal when the same\n" else "wrong\n")
