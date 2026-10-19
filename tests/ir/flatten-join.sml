(* dump: --passes=shake,simplify --dump-after=simplify *)
(* A join point whose parameter is a tuple it only takes apart, where a
   jump gives it a tuple made there (performance M8): its fields are the
   parameters instead, each jump gives the parts, and no tuple is made. *)
fun step (z : int, k : int, a : int, i : int) =
  let val (z, k) = if z < a then (a, i) else (z, k)
  in z + k end
val r = step (1, 2, 3, 4)
