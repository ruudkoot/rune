(* a functor's body, determined by a use of an application: the body,
   compiled once, is settled where it ends in every mode (MLton refuses it,
   Poly/ML accepts it) *)
functor F () = struct fun double x = x + x end
structure A = F ()
val y = A.double 2.0
val () = print (Real.toString y ^ "\n")
