(* determined only after a ; *)
val r = ref [];
val () = r := [1];
val () = print (Int.toString (length (!r)) ^ "\n");
