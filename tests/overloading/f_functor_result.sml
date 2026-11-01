(* in a functor's result, determined by a use of an application *)
functor F () = struct val id = (fn x => x) (fn x => x) end
structure A = F ()
val () = print (Int.toString (A.id 1) ^ "\n")
