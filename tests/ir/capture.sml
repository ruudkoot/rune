(* dump: --passes= --dump-after=lower *)
(* What a closure captures (Lower): a tuple whose parts are not made where
   it is bound (M11), since a field is taken of it (pick) or a constructor
   made of its fields (wrap), is made whole where the closure is, and the
   closure reads it from its environment and takes it apart -- the parts
   are variables of the function that binds it. *)
datatype u = P of int * int
fun pick (x, y) = let val p = (x + 1, y) in fn z => z + #1 p end
fun wrap (x, y) = let val p = (x + 1, y) in fn () => P p end
