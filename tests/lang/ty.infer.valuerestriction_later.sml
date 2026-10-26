(* --free-tyvars=later (the .cargs): a type variable a top-level
   declaration leaves free is what a later use in the program makes of it,
   past a `;`, as MLKit and Moscow ML have it; under the default, refuse,
   `val r = ref []` is refused where its top-level declaration ends *)
val r = ref [];
val () = r := [1, 2];
val () = print (Int.toString (length (!r)) ^ "\n");
