(* outer (* nested (* deeper *) *) still comment *)
val x = 1 (* trailing *)
val () = print (Int.toString x ^ "\n") (* (* *) *)
