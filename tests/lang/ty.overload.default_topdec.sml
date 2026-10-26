(* --overloading=topdec (the .cargs): an overloaded operator is determined
   by the top-level declaration, to a `;` or the end of the file, as
   Poly/ML and MLton have it; under the default, declaration, `+` defaults
   to int where `fun double` ends, and `double 2.0` is a type error *)
fun double x = x + x
val y = double 2.0
val () = print (Real.toString y ^ "\n")
