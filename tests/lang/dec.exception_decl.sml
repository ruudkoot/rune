exception Empty
exception Bad of string
exception Pair of int * int
fun f 0 = raise Empty | f 1 = raise Bad "one" | f 2 = raise Pair (2, 3) | f n = n
fun try n = (Int.toString (f n)) handle Empty => "empty" | Bad s => "bad " ^ s | Pair (a, b) => Int.toString (a + b)
val () = print (try 0 ^ "," ^ try 1 ^ "," ^ try 2 ^ "," ^ try 9 ^ "\n")
(* generative: each evaluation of a local exception declaration is distinct *)
fun mk () = let exception E in (E, fn x => (raise x) handle E => "mine" | _ => "other") end
val (e1, h1) = mk ()
val (e2, h2) = mk ()
val () = print (h1 e1 ^ h1 e2 ^ h2 e2 ^ "\n")
