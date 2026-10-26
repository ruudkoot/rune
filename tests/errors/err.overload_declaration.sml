(* --overloading=declaration (the .cargs), Appendix E's bound: `+` defaults
   to int where `fun double` ends, the smallest declaration at structure
   level around it, as SML/NJ and MLKit have it; the default, toplevel,
   accepts the structure whole *)
structure X = struct fun double x = x + x val y = double 2.0 end
val () = print (Real.toString X.y ^ "\n")
