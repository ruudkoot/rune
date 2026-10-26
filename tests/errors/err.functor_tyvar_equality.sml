(* Rule 89 at F's declaration (err.functor_tyvar_two_types), and rule 54
   besides: d does not admit equality in F's signature, t being a plain type
   of the parameter, whatever the argument (err.functor_equality). A copy
   of the body elaborated with t = int, which typed this application before
   such a functor was refused, found that S.d admits equality *)
functor F (type t) = struct datatype d = D of t val r = ref [] end
structure S = F (type t = int)
val () = S.r := [true]
val b = S.D 1 = S.D 1
val _ = print (if b then "accepted: S.d admits equality\n" else "false\n")
