(* the second unit: its own functor applied to the first unit's
   structure, and to one that opens it, and the first unit's functor
   applied to it -- each expanded here, where the argument's function is
   cast to unit at unit -> unit and back at int -> int, which the
   expansion folds by the function's scheme in the first unit's basis
   (generated functor programs, earlier_unit_arg; the lint refused it) *)
functor F (X : sig val mk : int -> int end) = struct fun mk n = X.mk n end
structure S = F (A)
structure B = struct open A end
structure T = F (B)
structure U = G (A)
val () = print (Int.toString (S.mk 1 + 10 * T.mk 2 + 100 * U.mk 3) ^ "\n")
