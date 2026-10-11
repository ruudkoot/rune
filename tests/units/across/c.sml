(* the third unit: sees the second's Store, raises the first's exception *)
val () = print (hd (!Store.items) ^ "\n")
val () = (raise Bad "caught") handle Bad s => print (s ^ "\n")
fun fail n = if n = 0 then raise Bad "uncaught" else 1 + fail (n - 1)
val _ = fail 3
