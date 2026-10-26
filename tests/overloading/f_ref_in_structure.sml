(* in a structure, determined by a later declaration *)
structure S = struct val r = ref [] end
val () = S.r := [1]
val () = print (Int.toString (length (!S.r)) ^ "\n")
