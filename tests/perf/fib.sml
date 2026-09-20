(* Baseline without the basis library: calls and int arithmetic. *)
fun fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)
val () = print (Int.toString (fib 24) ^ "\n")
