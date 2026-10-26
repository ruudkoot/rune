(* determined by the next declaration, no ; between *)
val r = ref []
val () = r := [1]
val () = print (Int.toString (length (!r)) ^ "\n")
