functor Inc (X : sig val n : int end) = struct val n = X.n + 1 end
functor Twice (X : sig val n : int end) = struct structure Once = Inc (X) structure Again = Inc (Once) val n = Again.n end
structure R = Twice (val n = 10)
val () = print (Int.toString R.n ^ " " ^ Int.toString R.Once.n ^ "\n")
(* a functor result as an argument, and let in a functor body *)
structure R2 = Inc (Twice (val n = 0))
val () = print (Int.toString R2.n ^ "\n")
functor L (X : sig val n : int end) = let val m = X.n * 3 in struct val n = m + 1 end end
structure R3 = L (R2)
val () = print (Int.toString R3.n ^ "\n")
