(* What a table's keys are: the parameter's signature, which the program's
   units and each implementation of Table are compiled against. *)
signature KEY =
sig
  type t
  val compare : t * t -> order
  val toString : t -> string
end
