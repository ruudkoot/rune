(* non-tail recursion 200000 deep through a call of a closure: the VM
   stack grows under a CALL, not only under a known call *)
fun apply f x = f x
fun sumTo 0 = 0 | sumTo n = n + apply sumTo (n - 1)
val () = print (Int.toString (sumTo 200000) ^ "\n")
fun build 0 = [] | build n = n :: apply build (n - 1)
val () = print (Int.toString (length (build 200000)) ^ "\n")
