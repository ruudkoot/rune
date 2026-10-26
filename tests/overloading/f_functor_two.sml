(* in a functor's result, used at two types by two applications: every
   application shares the variable, as the functor's signature does (rule
   54; MLton, which types each application by a copy of the body, accepts
   it) *)
functor F () = struct val r = ref [] end
structure A = F ()
structure B = F ()
val () = A.r := [1]
val () = B.r := ["x"]
val () = print (Int.toString (length (!A.r)) ^ "\n")
