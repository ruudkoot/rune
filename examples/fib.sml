(* Fibonacci numbers, naive and iterative. *)
fun fib 0 = 0
  | fib 1 = 1
  | fib n = fib (n - 1) + fib (n - 2)

fun fibIter n =
  let
    fun go (0, a, _) = a
      | go (k, a, b) = go (k - 1, b, a + b)
  in go (n, 0, 1) end

val () = print ("fib 25 = " ^ Int.toString (fib 25) ^ "\n")
val () = print ("fib 90 = " ^ Int.toString (fibIter 90) ^ "\n")
