(* --overloading=declaration (the .cargs, and the default), Appendix E's
   bound: `+` defaults to int where `fun double` ends, the smallest
   declaration at structure level around it, as SML/NJ and MLKit have it;
   --overloading=toplevel accepts the structure whole
   (tests/lang/ty.overload.default_toplevel) *)
structure X = struct fun double x = x + x val y = double 2.0 end
val () = print (Real.toString X.y ^ "\n")
