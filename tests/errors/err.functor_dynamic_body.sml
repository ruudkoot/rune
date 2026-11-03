(* A functor whose body is a dynamic module is not a dynamic functor
   (functor F = _dynamic "path" (X : S) : S): it is refused, as before *)
signature S = sig val x : int end
functor F (X : S) = _dynamic "f.rbu" : S
