(* A tuple used once, by a closure, as the argument of a constructor that
   is one object of its fields: the closure reads the tuple from its
   environment, and its fields from that. Lower once made the constructor
   of variables of mk, which the closure did not have, at every level. *)
datatype t = A of int * int | B

fun mk (x, y) =
  let val p = (x + 1, y + 2)
  in fn () => A p end

fun show (A (a, b)) = Int.toString a ^ " " ^ Int.toString b
  | show B = "B"

val fs = List.map mk [(10, 20), (30, 40), (50, 60)]
val () = List.app (fn f => print (show (f ()) ^ "\n")) fs
