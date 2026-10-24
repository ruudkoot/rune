(* Appendix E: the overloaded + of `fun double x = x + x`, in a functor's
   body, takes its default type int there, its smallest enclosing
   structure-level declaration (rule 86 elaborates the body once); the
   functor's signature has double : int -> int, rule 54 types T.double by
   it, and T.double 1.5 is a type error. Refused in every mode: the
   application and the use are two top-level declarations, and the copy a
   compile elaborates for the application has + settled where the first
   ends (mod.functor_overload_client has both in one, which a compile
   still accepts: the deviation Functors, corner (a)) *)
functor F () = struct fun double x = x + x end
structure T = F ()
val r = T.double 1.5
val _ = print (Real.toString r ^ "\n")
