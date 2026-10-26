(* Rule 89, as err.functor_tyvar_two_types, for a function: the body's
   `(fn x => x) (fn y => y)` is expansive, so id : 'a -> 'a with 'a free in
   F's signature, which rule 54 would give A.id and B.id alike, at int and
   at string *)
functor F () = struct val id = (fn x => x) (fn y => y) end
structure A = F ()
structure B = F ()
val a = A.id 1
val b = B.id "x"
val _ = print (Int.toString a ^ b ^ "\n")
