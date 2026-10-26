(* --free-tyvars=dummy (the .cargs): a type variable a value declaration at
   structure level leaves free is made a new type where the declaration
   ends, as SML/NJ's dummy types, so the next declaration cannot determine
   it *)
val r = ref []
val () = r := [1]
