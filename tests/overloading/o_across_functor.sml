(* determined after a functor's declaration, in the same topdec (Poly/ML
   accepts it, MLton refuses it) *)
fun double x = x + x
functor F () = struct end
val y = double 2.0
val () = print (Real.toString y ^ "\n")
