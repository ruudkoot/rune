(* Rule 89: no free type variable enters the basis. The body's r is a
   'a list ref whose 'a the value restriction leaves free (`ref []` is
   expansive: Sections 4.7 and 4.8, rule 15's Clos), so F's signature
   (rule 86) has it free; were F allowed, rule 54 would give A.r and B.r
   that one 'a, which cannot be int and string. Refused at the functor's
   declaration, as the Definition's Appendix G allows ("refuse elaboration
   in such situations") and HaMLet and MLKit do; a copy of the body for
   each application would give each r a variable of its own *)
functor F () = struct val r = ref [] end
structure A = F ()
structure B = F ()
val () = A.r := [1]
val () = B.r := ["x"]
val _ = print (Int.toString (length (!A.r) + length (!B.r)) ^ "\n")
