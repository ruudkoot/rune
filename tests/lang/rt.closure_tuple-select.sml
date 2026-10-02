(* A tuple used once, by a closure that takes a field of it: the closure
   reads the tuple from its environment, and the field of that. Lower once
   took the field from a variable of mk, which at -O0 the closure did not
   have. *)
fun mk (x, y) =
  let val p = (x * 3, y * 5)
  in fn z => z + #2 p end

val fs = List.map mk [(1, 2), (3, 4), (5, 6)]
val () = List.app (fn f => print (Int.toString (f 100) ^ "\n")) fs
