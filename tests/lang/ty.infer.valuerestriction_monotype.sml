(* --free-tyvars=monotype (the .cargs): a type variable a top-level
   declaration leaves free is made a new type where the top-level
   declaration ends, with a warning, as Poly/ML has it *)
val x = [] @ []
val () = print (Int.toString (length x) ^ "\n")
