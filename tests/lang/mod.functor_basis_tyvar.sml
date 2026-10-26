(* A type variable of the basis in a functor's result: r's, which the value
   restriction leaves free, determined by a declaration later in the same
   top-level declaration (no `;` between them). The Definition ACCEPTS it.
   Rules 87 to 89 ask that no type variable be free where the top-level
   declaration ends; F's signature shares r's variable, since rule 86
   elaborates the body in the basis that holds r and rule 54 renames type
   names apart, not type variables. So A.s and B.s are r, an int list ref.
   Every mode accepts it (the summary of F's body shares the variable), and
   it prints 1 7 *)
val r = ref []
functor F () = struct val s = r end
structure A = F ()
structure B = F ()
val () = A.s := [7]
val () = print (Int.toString (length (!B.s)) ^ " " ^ Int.toString (hd (!r)) ^ "\n")
