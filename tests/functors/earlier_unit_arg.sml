(* A functor declared and applied in one unit, to a structure of an earlier
   unit whose function the argument passes on: the expansion (D2 A) casts
   the function to unit from its type with unit for some parts (`unit ->
   unit` for `int -> int`, `unit ref -> unit` for `int ref -> int`) and back
   to its type, which --lint refused after expand at -O1 and -O2, in every
   mode in units and in --units --whole, while it printed right; `struct
   open A end` declared in the applying unit did too. The fold of the casts
   now takes the earlier unit's global's scheme from its basis (40f290078;
   tests/units/functor-earlier). *)
(* unit u0.sml *)
structure A = struct fun mk n = n end
(* unit u1.sml *)
functor F (X : sig val mk : int -> int end) = struct fun mk n = X.mk n end
structure S = F (A)
val () = print (Int.toString (S.mk 1) ^ "\n")
(* options inline=F --functor-budget=0 *)
