(* A functor declared and applied in one unit, to a structure of an earlier
   unit: the expansion (D2 A) casts the argument's function through unit
   from `unit -> unit` and back to `int -> int`, which --lint refuses after
   expand in every mode in units (and --units --whole). It
   prints right. The structure declared in the applying unit, or the functor
   applied in a later unit without --inline-functor, compiles clean. *)
(* unit u0.sml *)
structure A = struct fun mk n = n end
(* unit u1.sml *)
functor F (X : sig val mk : int -> int end) = struct fun mk n = X.mk n end
structure S = F (A)
val () = print (Int.toString (S.mk 1) ^ "\n")
(* options --inline-functor=F --functor-budget=0 *)
