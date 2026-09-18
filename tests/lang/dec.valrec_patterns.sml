(* Section 2.9 restricts only the right-hand side of val rec to fn: the
   pattern may be layered, typed, parenthesised or a wildcard, and every
   variable is bound to the same function *)
val rec ((f)) = fn 0 => 1 | n => n * f (n - 1)
val rec g as h as (k : int -> int) = fn 0 => 0 | n => 1 + h (n - 1)
val rec _ = fn () => ()
val rec p : int -> int as q = fn 0 => 7 | n => p (n - 1)
val () = print (Int.toString (f 5) ^ " " ^ Int.toString (g 3 + h 2 + k 1) ^ " " ^ Int.toString (q 4) ^ "\n")
